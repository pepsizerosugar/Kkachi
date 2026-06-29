import Foundation
@testable import Kkachi

/// Creates shared tracker contexts for tests that need one deterministic fake browser.
@MainActor
enum TabTrackerTestContexts {
    /// Creates a tracker/store pair that starts with one browser disabled.
    static func disabled() -> (adapter: FakeBrowserAdapter, tracker: TabTracker, store: KkachiStore) {
        let adapter = FakeBrowserAdapter(tabs: [.sample(isActive: false)])
        let context = enabled(adapter: adapter) { preferences in
            preferences.setBrowser(adapter.descriptor.id, enabled: false)
        }
        let store = KkachiStore(
            preferences: context.preferences,
            tracker: context.tracker,
            loginItemService: FakeLoginItemService(),
            applicationOpener: FakeApplicationOpener(),
            pasteboardWriter: FakePasteboardWriter()
        )
        return (context.adapter, context.tracker, store)
    }

    /// Creates a tracker context that starts with browser polling enabled.
    static func enabled(
        tabs: [BrowserTabSnapshot] = [.sample(isActive: false)],
        adapter providedAdapter: FakeBrowserAdapter? = nil,
        configurePreferences: ((PreferencesStore) -> Void)? = nil
    ) -> (adapter: FakeBrowserAdapter, preferences: PreferencesStore, tracker: TabTracker) {
        let adapter = providedAdapter ?? FakeBrowserAdapter(tabs: tabs)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        configurePreferences?(preferences)
        let tracker = TabTracker(
            adapters: [adapter],
            preferences: preferences,
            historyStore: FakeRestoreHistoryStore(),
            workspaceNotifications: .testing()
        )
        return (adapter, preferences, tracker)
    }

    /// Waits longer than the production policy-poll delay without exposing it publicly.
    static func waitForDeferredPolicyPoll() async throws {
        try await Task.sleep(nanoseconds: 450_000_000)
    }
}
