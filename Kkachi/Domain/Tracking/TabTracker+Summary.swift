import Foundation

/// Derives the menu-facing summary and row ordering from the tracker's live tabs. Split out of
/// `TabTracker+Evaluation` to keep that file within the project's length budget; these are pure
/// transforms over already-evaluated `TrackedTab` rows with no side effects on tracker state.
@MainActor
extension TabTracker {
    /// Sorts protected/active rows after soon-to-prune rows for fast scanning.
    func sortTrackedTabs(_ tabs: [TrackedTab]) -> [TrackedTab] {
        tabs.sorted { lhs, rhs in
            switch (lhs.pruneAt, rhs.pruneAt) {
            case let (left?, right?):
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.hostLabel < rhs.hostLabel
            }
        }
    }

    /// Creates the compact dashboard summary from live tracked rows. Auto-close-blocked rows are kept out
    /// of the "closing soon" count and the next-prune date so every count-driven surface (header, mood,
    /// menu-bar mark) stays honest about what Kkachi will actually close; they are counted separately so a
    /// dedicated header can own them.
    func makeSummary(from tabs: [TrackedTab]) -> TrackingSummary {
        let eligibleTabs = tabs.filter { !$0.isActive && !$0.isExcluded && $0.pruneAt != nil && !$0.isAutoCloseBlocked }
        let nextPruneAt = eligibleTabs.compactMap(\.pruneAt).min()
        let protectedCount = tabs.filter(\.isExcluded).count
        let atRiskCount = tabs.filter { $0.isAtRisk && !$0.isAutoCloseBlocked }.count
        let blockedCount = tabs.filter(\.isAutoCloseBlocked).count

        return TrackingSummary(scannedCount: tabs.count, atRiskCount: atRiskCount, blockedCount: blockedCount, protectedCount: protectedCount, nextPruneAt: nextPruneAt)
    }

    /// Defines how close to pruning a tab must be before the UI calls it at risk.
    static func atRiskWindow(for policy: PrunePolicy) -> TimeInterval {
        PruneEvaluator.atRiskWindow(for: policy)
    }
}
