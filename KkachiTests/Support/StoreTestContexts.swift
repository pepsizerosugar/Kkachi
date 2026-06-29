import Foundation
@testable import Kkachi

/// Bundles the store and fakes that tests commonly inspect together.
@MainActor
struct StoreTestContext {
    /// Drives browser state for tracker and permission tests.
    let automation: FakeBrowserAdapter

    /// Keeps preference mutations isolated to one test.
    let preferences: PreferencesStore

    /// Owns live tab and history state exposed through the store.
    let tracker: TabTracker

    /// Captures Launch at Login requests without touching the OS.
    let loginItemService: FakeLoginItemService

    /// Captures URL and app-open side effects from restore flows.
    let applicationOpener: FakeApplicationOpener

    /// Captures pasteboard writes from restore fallback commands.
    let pasteboardWriter: FakePasteboardWriter

    /// Exposes the UI-facing store under test.
    let store: KkachiStore
}

/// Creates store test contexts with isolated preferences and deterministic fakes.
@MainActor
enum StoreTestContexts {
    /// Creates a store stack while allowing tests to customize only their meaningful fixture state.
    static func make(
        tabs: [BrowserTabSnapshot] = [],
        automation providedAutomation: FakeBrowserAdapter? = nil,
        loginItemService providedLoginItemService: FakeLoginItemService? = nil,
        applicationOpener providedApplicationOpener: FakeApplicationOpener? = nil,
        pasteboardWriter providedPasteboardWriter: FakePasteboardWriter? = nil,
        configurePreferences: ((PreferencesStore) -> Void)? = nil
    ) -> StoreTestContext {
        let automation = providedAutomation ?? FakeBrowserAdapter(tabs: tabs)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        configurePreferences?(preferences)
        let tracker = TabTracker(
            adapters: [automation],
            preferences: preferences,
            historyStore: FakeRestoreHistoryStore(),
            workspaceNotifications: .testing()
        )
        let loginItemService = providedLoginItemService ?? FakeLoginItemService()
        let applicationOpener = providedApplicationOpener ?? FakeApplicationOpener()
        let pasteboardWriter = providedPasteboardWriter ?? FakePasteboardWriter()
        let store = KkachiStore(
            preferences: preferences,
            tracker: tracker,
            loginItemService: loginItemService,
            applicationOpener: applicationOpener,
            pasteboardWriter: pasteboardWriter
        )
        return StoreTestContext(
            automation: automation,
            preferences: preferences,
            tracker: tracker,
            loginItemService: loginItemService,
            applicationOpener: applicationOpener,
            pasteboardWriter: pasteboardWriter,
            store: store
        )
    }
}
