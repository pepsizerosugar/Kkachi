import Foundation

/// Describes one pruning attempt without exposing adapter implementation details.
enum PruneAttemptResult {
    /// Indicates the tab was closed by Kkachi and entered restore history.
    case pruned

    /// Indicates the tab was already gone — the user closed it by hand mid-cycle. The stale row is
    /// dropped without restore history, and the browser is NOT marked close-failed (it was no failure).
    case alreadyClosed

    /// Indicates Kkachi deliberately kept the tab open for safety.
    case skipped

    /// Indicates automation failed and should surface as an error.
    case failed
}

/// Evaluates live browser snapshots against pruning policy.
@MainActor
extension TabTracker {
    /// Updates inactivity timestamps and prunes expired inactive tabs.
    func evaluate(_ tabs: [BrowserTabSnapshot], now: Date) -> Bool {
        KkachiDebugLog.pruning("evaluate start tabCount=\(tabs.count) now=\(now.timeIntervalSince1970)")
        activeBatchID = nil
        let evaluation = PruneEvaluator.evaluate(
            tabs: tabs,
            policy: currentPolicy,
            lastActiveDates: lastActiveDates,
            browserStatuses: browserStatuses,
            closeFailedBrowsers: closeFailedBrowsers,
            now: now
        )
        lastActiveDates = evaluation.lastActiveDates
        var nextTrackedTabs = evaluation.trackedTabs
        var hadPruneError = false

        for candidate in evaluation.pruneCandidates {
            KkachiDebugLog.pruning("tab expired \(KkachiDebugLog.tabContext(candidate.tab)) now=\(now.timeIntervalSince1970) pruneAt=\(candidate.blockedRow.pruneAt?.timeIntervalSince1970 ?? -1)")
            switch prune(candidate.tab, prunedAt: now) {
            case .pruned, .alreadyClosed:
                break
            case .skipped:
                nextTrackedTabs.append(candidate.blockedRow)
            case .failed:
                nextTrackedTabs.append(candidate.blockedRow)
                hadPruneError = true
            }
        }

        trackedTabs = sortTrackedTabs(nextTrackedTabs)
        summary = makeSummary(from: trackedTabs)
        finishPruneCycle(now: now)
        KkachiDebugLog.pruning("evaluate finish trackedCount=\(trackedTabs.count) atRisk=\(summary.atRiskCount) protected=\(summary.protectedCount) hadPruneError=\(hadPruneError)")
        return hadPruneError
    }

    /// Captures context, closes the tab, and appends restore history if expired.
    func prune(_ tab: BrowserTabSnapshot, prunedAt: Date) -> PruneAttemptResult {
        guard !closeFailedBrowsers.contains(tab.identity.browserID) else {
            KkachiDebugLog.pruning("prune skipped reason=closeFailedThisSession \(KkachiDebugLog.tabContext(tab))")
            return .skipped
        }
        guard browserStatuses.first(where: { $0.id == tab.identity.browserID })?.isEligibleForPruning == true else {
            KkachiDebugLog.pruning("prune skipped reason=browserNotEligible \(KkachiDebugLog.tabContext(tab))")
            return .skipped
        }
        if tab.isIdentityAmbiguous {
            KkachiDebugLog.pruning("prune skipped reason=ambiguousIdentity \(KkachiDebugLog.tabContext(tab))")
            return .skipped
        }
        do {
            guard let adapter = adapterByID[tab.identity.browserID] else {
                throw BrowserAutomationError.executionFailed(operation: "closeTab", details: "unsupportedBrowser")
            }
            let currentMediaState = try adapter.mediaState(for: tab)
            guard currentMediaState == .notPlaying else {
                KkachiDebugLog.pruning("prune skipped reason=mediaState \(KkachiDebugLog.tabContext(tab)) state=\(currentMediaState)")
                return .skipped
            }
            KkachiDebugLog.pruning("prune attempt \(KkachiDebugLog.tabContext(tab))")
            let closeResult = try adapter.closeTab(tab)
            KkachiDebugLog.pruning("prune closeResult=\(closeResult) \(KkachiDebugLog.tabContext(tab))")
            guard closeResult == .closed else { return .skipped }
            appendHistory(from: tab, prunedAt: prunedAt)
            lastActiveDates.removeValue(forKey: tab.stableID)
            KkachiDebugLog.pruning("prune success historyCount=\(prunedTabs.count) \(KkachiDebugLog.tabContext(tab))")
            return .pruned
        } catch {
            if Self.isTargetMissing(error) {
                KkachiDebugLog.pruning("prune target already gone \(KkachiDebugLog.tabContext(tab)) error=\(String(describing: error))")
                lastActiveDates.removeValue(forKey: tab.stableID)
                return .alreadyClosed
            }
            KkachiDebugLog.pruning("prune failed \(KkachiDebugLog.tabContext(tab)) error=\(String(describing: error))")
            closeFailedBrowsers.insert(tab.identity.browserID)
            if let adapter = adapterByID[tab.identity.browserID] {
                updateStatus(for: adapter, automationState: automationFailureState(for: error), error: error)
            }
            lastErrorDescription = String(describing: error)
            return .failed
        }
    }

    /// Returns true when a close error means the close target no longer exists — the user closed the tab
    /// or window by hand mid-cycle ("tabMissing"/"windowMissing"), or quit the whole browser between this
    /// cycle's fetch and the close attempt ("applicationNotRunning"). None of these are automation
    /// failures, so they must never poison the browser. The detail strings are the automation
    /// contract for a vanished target.
    static func isTargetMissing(_ error: Error) -> Bool {
        guard case let BrowserAutomationError.executionFailed(_, details) = error else { return false }
        return details == "tabMissing" || details == "windowMissing" || details == "applicationNotRunning"
    }

    /// Decides global status after a poll: a single flaky browser stays a per-browser problem, and
    /// the menu only shows a global automation error when no runnable browser could be reached at all.
    func resolvePollStatus(succeededCount: Int, hadPollingError: Bool, hadPruneError: Bool) {
        if succeededCount > 0 {
            status = .running
            if !hadPollingError, !hadPruneError { lastErrorDescription = nil }
        } else if hadPollingError {
            status = .automationError
        }
    }

}
