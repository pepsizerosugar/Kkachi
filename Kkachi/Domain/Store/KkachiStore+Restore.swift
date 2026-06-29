import Foundation

/// Groups restore-history commands and the restore-failure fallback so the core store stays small.
@MainActor
extension KkachiStore {
    /// Restores one pruned tab through the tracker and reports whether history changed.
    @discardableResult
    func restore(_ tab: PrunedTab) -> Bool {
        tracker.restore(tab)
    }

    /// Restores the most recent history item for a fast undo flow.
    @discardableResult
    func restoreLastPrunedTab() -> Bool {
        guard let tab = prunedTabs.first else { return false }

        return tracker.restore(tab)
    }

    /// Reopens every tab from the most recent close cycle in one tap, so a multi-tab cleanup undoes as a
    /// single action. Returns how many reopened for optional confirmation.
    @discardableResult
    func restoreLastBatch() -> Int {
        tracker.restoreLastBatch()
    }

    /// Reopens a specific close batch by id string, used by the close notification so an old banner
    /// reopens the batch it named rather than the most recent one.
    @discardableResult
    func restoreBatch(idString: String) -> Int {
        tracker.restoreBatch(idString: idString)
    }

    /// Counts the still-restorable tabs from the most recent close cycle (the leading run of history that
    /// shares one batch id). Greater than one means the menu should offer "Closed N tabs · Reopen all"
    /// instead of a single-tab undo; derived from persisted history so it survives relaunch.
    var recentBatchCount: Int {
        guard let leadBatchID = prunedTabs.first?.batchID else { return 0 }
        return prunedTabs.prefix { $0.batchID == leadBatchID }.count
    }

    /// Surfaces the brief post-close acknowledgement window so the menu-bar mark and hero can show that
    /// Kkachi just pruned, then settle back automatically.
    var isPruningInProgress: Bool {
        tracker.isPruningInProgress
    }

    /// Clears durable restore history without touching live tracking state.
    func clearHistory() {
        tracker.clearHistory()
    }

    /// Exposes the most recent restore failure, but only while its row is still present, so the
    /// fallback banner disappears automatically once the tab is reopened or the history is cleared.
    var restoreFailure: RestoreFailure? {
        guard let failure = tracker.restoreFailure,
              prunedTabs.contains(where: { $0.id == failure.tabID }) else { return nil }
        return failure
    }

    /// Reopens a tab that could not restore in its origin browser using the default browser, then
    /// drops the history row — the page is back, just somewhere else, so the promise is kept.
    func restoreInDefaultBrowser(_ tab: PrunedTab) {
        applicationOpener.openURL(tab.url)
        tracker.acceptDefaultBrowserFallback(for: tab)
    }

    /// Copies a pruned tab's URL to the pasteboard so the user never loses the page even if reopening fails.
    func copyURL(_ tab: PrunedTab) {
        pasteboardWriter.copy(tab.url.absoluteString)
    }
}
