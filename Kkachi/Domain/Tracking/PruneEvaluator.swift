import Foundation

/// Carries an expired tab that is safe to attempt closing plus the row to show if closing cannot finish.
struct PruneCandidate: Equatable {
    let tab: BrowserTabSnapshot
    let blockedRow: TrackedTab
}

/// Returns pure pruning decisions without invoking browser automation.
struct PruneEvaluationResult: Equatable {
    let trackedTabs: [TrackedTab]
    let pruneCandidates: [PruneCandidate]
    let lastActiveDates: [String: Date]
}

/// Evaluates tab snapshots against policy while leaving destructive close decisions to the coordinator.
enum PruneEvaluator {
    static func evaluate(
        tabs: [BrowserTabSnapshot],
        policy: PrunePolicy,
        lastActiveDates currentDates: [String: Date],
        browserStatuses: [BrowserStatus],
        closeFailedBrowsers: Set<BrowserID>,
        now: Date
    ) -> PruneEvaluationResult {
        let observedIDs = Set(tabs.map(\.stableID))
        let eligibility = Dictionary(uniqueKeysWithValues: browserStatuses.map { ($0.id, $0.isEligibleForPruning) })
        var lastActiveDates = currentDates.filter { observedIDs.contains($0.key) }
        var trackedTabs: [TrackedTab] = []
        var pruneCandidates: [PruneCandidate] = []

        for tab in tabs {
            if tab.isActive || lastActiveDates[tab.stableID] == nil {
                lastActiveDates[tab.stableID] = now
            }

            let lastActive = lastActiveDates[tab.stableID] ?? now
            let isExcluded = policy.exclusions.contains { $0.matches(tab.url) }
            let pruneAt = tab.isActive || isExcluded ? nil : lastActive.addingTimeInterval(policy.inactivityThreshold)
            let isAtRisk = pruneAt.map { $0.timeIntervalSince(now) <= atRiskWindow(for: policy) } ?? false

            guard let pruneAt, now >= pruneAt else {
                trackedTabs.append(trackedTab(from: tab, lastActive: lastActive, isExcluded: isExcluded, pruneAt: pruneAt, isAtRisk: isAtRisk))
                continue
            }

            let blockedRow = trackedTab(from: tab, lastActive: lastActive, isExcluded: isExcluded, pruneAt: pruneAt, isAtRisk: true, isAutoCloseBlocked: true)
            if closeFailedBrowsers.contains(tab.identity.browserID) || eligibility[tab.identity.browserID] != true || tab.isIdentityAmbiguous {
                trackedTabs.append(blockedRow)
            } else {
                pruneCandidates.append(PruneCandidate(tab: tab, blockedRow: blockedRow))
            }
        }

        return PruneEvaluationResult(trackedTabs: trackedTabs, pruneCandidates: pruneCandidates, lastActiveDates: lastActiveDates)
    }

    static func atRiskWindow(for policy: PrunePolicy) -> TimeInterval {
        max(60, min(policy.inactivityThreshold * 0.2, 5 * 60))
    }

    private static func trackedTab(
        from tab: BrowserTabSnapshot,
        lastActive: Date,
        isExcluded: Bool,
        pruneAt: Date?,
        isAtRisk: Bool,
        isAutoCloseBlocked: Bool = false
    ) -> TrackedTab {
        TrackedTab(
            id: tab.stableID,
            browserID: tab.identity.browserID,
            identity: tab.identity,
            browserNameKey: tab.browserNameKey,
            title: tab.title,
            url: tab.url,
            lastActiveAt: lastActive,
            isActive: tab.isActive,
            isExcluded: isExcluded,
            pruneAt: pruneAt,
            isAtRisk: isAtRisk,
            isIdentityAmbiguous: tab.isIdentityAmbiguous,
            isAutoCloseBlocked: isAutoCloseBlocked
        )
    }
}
