#if DEBUG
import Foundation

/// Builds large deterministic UI-test datasets without real browser automation.
enum KkachiUITestStressFixtures {
    /// Converts an optional launch-environment value into a nonnegative tab count.
    static func tabCount(from rawValue: String?) -> Int {
        guard let rawValue, let count = Int(rawValue), count > 0 else { return 0 }
        return count
    }

    /// Creates live browser snapshots that the fake adapter can reveal or close.
    static func snapshots(count: Int, descriptor: BrowserDescriptor) -> [BrowserTabSnapshot] {
        (0..<count).map { snapshot(index: $0, descriptor: descriptor) }
    }

    /// Creates already-derived at-risk rows so UI stress tests skip slow Apple Events setup.
    static func trackedTabs(count: Int, descriptor: BrowserDescriptor, now: Date = Date()) -> [TrackedTab] {
        snapshots(count: count, descriptor: descriptor).map { snapshot in
            let lastActive = now.addingTimeInterval(-PrunePolicy.default.inactivityThreshold + 120)
            let pruneAt = now.addingTimeInterval(120)
            return TrackedTab(
                id: snapshot.stableID,
                browserID: descriptor.id,
                identity: snapshot.identity,
                browserNameKey: descriptor.displayNameKey,
                title: snapshot.title,
                url: snapshot.url,
                lastActiveAt: lastActive,
                isActive: false,
                isExcluded: false,
                pruneAt: pruneAt,
                isAtRisk: true,
                isIdentityAmbiguous: false,
                isAutoCloseBlocked: false
            )
        }
    }

    /// Summarizes injected rows the same way a real polling pass would for the menu.
    static func summary(for tabs: [TrackedTab]) -> TrackingSummary {
        let nextPruneAt = tabs.compactMap(\.pruneAt).min()
        return TrackingSummary(scannedCount: tabs.count, atRiskCount: tabs.count, blockedCount: 0, protectedCount: 0, nextPruneAt: nextPruneAt)
    }

    /// Builds one tab snapshot with unique identity and realistic URL/title values.
    private static func snapshot(index: Int, descriptor: BrowserDescriptor) -> BrowserTabSnapshot {
        let host = "stress\(index % 50).example.com"
        let url = URL(string: "https://\(host)/articles/\(index)")!
        let title = title(for: index)
        let identity = BrowserTabIdentity(
            browserID: descriptor.id,
            windowID: "\(index / 40)",
            tabID: "\(index)",
            windowIndex: nil,
            tabIndex: nil,
            fingerprint: BrowserTabFingerprint(url: url, title: title)
        )
        return BrowserTabSnapshot(identity: identity, url: url, title: title, isActive: false, browserNameKey: descriptor.displayNameKey)
    }

    /// Provides varied fixture titles without adding production localization keys.
    private static func title(for index: Int) -> String {
        index.isMultiple(of: 25) ? "Very Long Reading Queue Entry \(index) With Extra Context" : "Stress Tab \(index)"
    }
}
#endif
