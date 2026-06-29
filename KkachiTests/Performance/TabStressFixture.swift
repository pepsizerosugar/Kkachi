import Foundation
@testable import Kkachi

/// Builds deterministic high-volume browser data for performance and stress tests.
enum TabStressFixture {
    /// Keeps the user-requested fast stress tiers visible in one test-owned place.
    static let requestedCounts = [100, 500, 1_000]

    /// Creates a tracker context that exercises policy, sorting, and adapter boundaries.
    @MainActor
    static func makeTracker(tabCount: Int, descriptor: BrowserDescriptor = .testChrome) -> (tracker: TabTracker, adapter: FakeBrowserAdapter) {
        let adapter = FakeBrowserAdapter(tabs: tabs(count: tabCount, descriptor: descriptor), descriptor: descriptor)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        preferences.addExclusion("docs.example.com")
        let tracker = TabTracker(adapters: [adapter], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())
        return (tracker, adapter)
    }

    /// Creates varied but stable snapshots for a single fake browser.
    static func tabs(count: Int, descriptor: BrowserDescriptor = .testChrome) -> [BrowserTabSnapshot] {
        (0..<count).map { snapshot(index: $0, descriptor: descriptor) }
    }

    /// Ages inactive tabs beyond the pruning threshold without changing active rows.
    @MainActor
    static func expireInactiveTabs(on tracker: TabTracker, tabs: [BrowserTabSnapshot], now: Date) {
        let expiredDate = now.addingTimeInterval(-PrunePolicy.default.inactivityThreshold - 10)
        for tab in tabs where !tab.isActive {
            tracker.lastActiveDates[tab.stableID] = expiredDate
        }
    }

    /// Builds one snapshot with window, active, excluded, and ambiguity variation.
    private static func snapshot(index: Int, descriptor: BrowserDescriptor) -> BrowserTabSnapshot {
        let host = index.isMultiple(of: 10) ? "docs.example.com" : "site\(index % 37).example.net"
        let url = URL(string: "https://\(host)/workspace/\(index)")!
        let title = title(for: index)
        let identity = BrowserTabIdentity(
            browserID: descriptor.id,
            windowID: "\(index / 25)",
            tabID: "\(index)",
            windowIndex: nil,
            tabIndex: nil,
            fingerprint: BrowserTabFingerprint(url: url, title: title)
        )
        return BrowserTabSnapshot(
            identity: identity,
            url: url,
            title: title,
            isActive: index.isMultiple(of: 31),
            browserNameKey: descriptor.displayNameKey,
            isIdentityAmbiguous: index.isMultiple(of: 37)
        )
    }

    /// Provides short and long titles without depending on localized UI strings.
    private static func title(for index: Int) -> String {
        index.isMultiple(of: 40) ? "Research Note \(index) Section Section Section Section" : "Tab \(index)"
    }
}
