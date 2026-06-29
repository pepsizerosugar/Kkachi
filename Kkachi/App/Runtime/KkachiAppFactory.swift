import Foundation

/// Assembles production dependencies so domain objects never construct platform infrastructure.
@MainActor
enum KkachiAppFactory {
    static func makeStore() -> KkachiStore {
        let preferences = PreferencesStore()
        let tracker = TabTracker(
            adapters: BrowserRegistry().makeAdapters(),
            preferences: preferences,
            historyStore: RestoreHistoryStore(),
            workspaceNotifications: SystemWorkspaceNotifications.source
        )
        return KkachiStore(
            preferences: preferences,
            tracker: tracker,
            loginItemService: SystemLoginItemService(),
            applicationOpener: WorkspaceApplicationOpener(),
            pasteboardWriter: SystemPasteboardWriter()
        )
    }
}
