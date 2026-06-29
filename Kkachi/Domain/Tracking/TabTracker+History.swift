import Foundation

/// Identifies why a restore could not reopen a page, so the menu can explain it instead of failing silently.
enum RestoreFailureReason: Equatable {
    /// The origin browser is installed but did not respond to automation.
    case browserNotRunning
    /// The origin browser is no longer installed on this Mac.
    case browserUnavailable
    /// The reopen failed for another reason (generic automation failure).
    case couldNotReopen

    /// Maps each reason to a catalog key so the menu never shows a hardcoded string.
    var localizationKey: String {
        switch self {
        case .browserNotRunning: return "menu.history.restoreFailure.browserNotRunning"
        case .browserUnavailable: return "menu.history.restoreFailure.browserUnavailable"
        case .couldNotReopen: return "menu.history.restoreFailure.couldNotReopen"
        }
    }
}

/// Records the most recent restore that could not reopen, so the UI can offer a fallback rather than
/// collapsing the whole menu into a generic automation-error state.
struct RestoreFailure: Equatable {
    /// Identifies the history row that failed to reopen.
    let tabID: PrunedTab.ID
    /// Explains why the reopen failed, for legible and honest feedback.
    let reason: RestoreFailureReason
}

/// Keeps restore-history commands separate from polling lifecycle code.
@MainActor
extension TabTracker {
    /// Restores a selected history item and removes it only after browser automation succeeds.
    @discardableResult
    func restore(_ tab: PrunedTab) -> Bool {
        do {
            guard let adapter = adapterByID[tab.browserID] else {
                throw BrowserAutomationError.executionFailed(operation: "restoreTab", details: "unsupportedBrowser")
            }
            try adapter.restore(tab)
            prunedTabs.removeAll { $0.id == tab.id }
            restoreFailure = nil
            persistHistory()
            return true
        } catch {
            restoreFailure = RestoreFailure(tabID: tab.id, reason: classifyRestoreFailure(for: tab))
            rememberAutomationError(error)
            return false
        }
    }

    /// Drops a history row after the user reopened it in the default browser, persisting the change.
    func acceptDefaultBrowserFallback(for tab: PrunedTab) {
        prunedTabs.removeAll { $0.id == tab.id }
        restoreFailure = nil
        persistHistory()
    }

    /// Reopens every tab from the most recent close batch in one action, newest first, so a multi-tab
    /// cleanup is reversible with a single tap. Stops at the first failure (which surfaces its own
    /// fallback banner) and returns how many tabs reopened, so callers can confirm the batch undo.
    @discardableResult
    func restoreLastBatch() -> Int {
        let targets = RestoreHistoryController.recentBatch(in: prunedTabs)
        var restored = 0
        for tab in targets {
            guard restore(tab) else { break }
            restored += 1
        }
        return restored
    }

    /// Clears restore history, on disk and in memory, when the user explicitly requests it.
    func clearHistory() {
        prunedTabs.removeAll()
        restoreFailure = nil
        lastPruneBatch = nil
        persistHistory()
    }

    /// Inserts a pruned tab under the current cycle's batch id — created lazily on the first close so
    /// quiet polls allocate nothing — enforces the memory cap, and records it for this cycle's batch
    /// summary. The single funnel that turns a closed tab into restorable history.
    func appendHistory(from tab: BrowserTabSnapshot, prunedAt: Date) {
        RestoreHistoryController.append(tab, prunedAt: prunedAt, activeBatchID: &activeBatchID, prunedTabs: &prunedTabs, historyLimit: Self.historyLimit)
        persistHistory()
    }

    /// Publishes the cycle's close batch once polling finishes: records the "Closed N tabs" summary,
    /// flips a brief pruning acknowledgement for the menu-bar mark, and posts the optional system
    /// notification once. The batch is gathered from the already memory-capped history (not a separate
    /// accumulator) so its count can never claim more tabs than are actually restorable. A cycle that
    /// closed nothing leaves all of this untouched, so quiet polls stay silent.
    func finishPruneCycle(now: Date) {
        guard let batchID = activeBatchID else { return }
        let tabs = prunedTabs.filter { $0.batchID == batchID }
        guard !tabs.isEmpty else { return }
        let batch = PruneBatch(id: batchID, tabs: tabs, closedAt: now)
        lastPruneBatch = batch
        isPruningInProgress = true
        pruningResetTask?.cancel()
        pruningResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.isPruningInProgress = false
        }
        if preferences.policy.notifyOnPrune {
            pruneNotifier?.notifyPruned(batch)
        }
        activeBatchID = nil
    }

    /// Reopens every still-restorable tab from a specific close batch, identified by its id string (the
    /// notification carries this so tapping an old "Closed N tabs" banner reopens THAT batch — not
    /// whatever was closed most recently). Already-reopened rows are simply skipped.
    @discardableResult
    func restoreBatch(idString: String) -> Int {
        let targets = RestoreHistoryController.batch(idString: idString, in: prunedTabs)
        var restored = 0
        for tab in targets {
            guard restore(tab) else { break }
            restored += 1
        }
        return restored
    }

    /// Writes the current restore history to disk; the single funnel for durability.
    func persistHistory() {
        historyStore.save(prunedTabs)
    }

    /// Classifies a restore failure from current browser readiness so the message matches reality.
    private func classifyRestoreFailure(for tab: PrunedTab) -> RestoreFailureReason {
        RestoreHistoryController.failureReason(for: tab, browserStatuses: browserStatuses)
    }
}
