import AppKit
import Combine
import SwiftUI

/// Coordinates app lifecycle events that need AppKit hooks unavailable on `App`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// Gives SwiftUI menu controls a stable route to AppKit lifecycle operations.
    static private(set) var shared: AppDelegate?

    /// Owns the production app store lazily so UI-test launches avoid real browser adapters.
    private var productionStore: KkachiStore?

    /// Owns the static menu-bar item and SwiftUI popover bridge.
    private var menuBarStatusController: MenuBarStatusController?

    /// Retains the AppKit-hosted Settings window used by the menu-bar activation path.
    private var settingsWindow: NSWindow?

    /// Retains store subscriptions owned by AppKit runtime bridges.
    private var cancellables: Set<AnyCancellable> = []

#if DEBUG
    /// Owns the deterministic window used only by XCUITest launches.
    private var uiTestHarness: KkachiUITestHarness?
#endif

    /// Registers the delegate before SwiftUI creates menu content that can request Settings.
    override init() {
        super.init()
        Self.shared = self
    }

    /// Provides the store used by the app-level Settings scene.
    var settingsStore: KkachiStore {
#if DEBUG
        if KkachiUITestHarness.isEnabled {
            return ensureUITestHarness().store
        }
#endif
        return ensureProductionStore()
    }

    /// Detects XCTest host launches so tests do not run real browser automation.
    private var isRunningUnderTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Starts background tab monitoring once macOS has finished launching the agent app.
    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        if KkachiUITestHarness.isEnabled {
            NSApp.setActivationPolicy(.regular)
            let harness = ensureUITestHarness()
            harness.start()
            return
        }
#endif
        NSApp.setActivationPolicy(.accessory)
        if !isRunningUnderTests {
            let store = ensureProductionStore()
            let statusController = MenuBarStatusController(store: store)
            statusController.start()
            menuBarStatusController = statusController
            store.tracker.pruneNotifier = PruneNotifier(
                languageProvider: { [weak store] in store?.preferences.appLanguage ?? .system },
                onReopen: { [weak store] id in store?.restoreBatch(idString: id) }
            )
            store.start()
        }
    }

    /// Stops timers and observers before the process exits to avoid late callbacks.
    func applicationWillTerminate(_ notification: Notification) {
        menuBarStatusController?.stop()
        productionStore?.stop()
    }

    /// Presents Settings from menu-bar UI without relying on SwiftUI SettingsLink focus behavior.
    func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        let window = ensureSettingsWindow()
        window.title = settingsWindowTitle(for: settingsStore)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Restores the app to menu-bar-only behavior after the AppKit Settings window closes.
    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow, closedWindow === settingsWindow else {
            return
        }

        settingsWindow = nil
#if DEBUG
        if KkachiUITestHarness.isEnabled {
            return
        }
#endif
        NSApp.setActivationPolicy(.accessory)
    }

    /// Creates the production store only for real app launches.
    private func ensureProductionStore() -> KkachiStore {
        if let productionStore {
            return productionStore
        }

        let store = KkachiAppFactory.makeStore()
        productionStore = store
        observeLanguageChanges(for: store)
        return store
    }

    /// Creates the reusable Settings window around the same SwiftUI form used by the Settings scene.
    private func ensureSettingsWindow() -> NSWindow {
        if let settingsWindow {
            return settingsWindow
        }

        let store = settingsStore
        let hostingController = NSHostingController(rootView: KkachiLocalizedRoot(store: store) {
            SettingsView(store: store)
        })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("kkachi.settingsWindow")
        window.title = settingsWindowTitle(for: store)
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window
        return window
    }

    /// Keeps AppKit-owned Settings chrome aligned with the selected app language.
    private func observeLanguageChanges(for store: KkachiStore) {
        store.objectWillChange.sink { [weak self, weak store] _ in
            Task { @MainActor in
                await Task.yield()
                guard let self, let store else { return }
                self.settingsWindow?.title = self.settingsWindowTitle(for: store)
            }
        }
        .store(in: &cancellables)
    }

    /// Resolves the Settings window title through the app-language preference.
    private func settingsWindowTitle(for store: KkachiStore) -> String {
        AppLocalization.string("menu.footer.settings", language: store.preferences.appLanguage)
    }

#if DEBUG
    /// Creates the deterministic harness once so SettingsLink and the menu share test state.
    private func ensureUITestHarness() -> KkachiUITestHarness {
        if let uiTestHarness {
            return uiTestHarness
        }

        let harness = KkachiUITestHarness()
        uiTestHarness = harness
        return harness
    }
#endif
}

/// Defines the menu-bar-only SwiftUI application entry point.
@main
struct KkachiApp: App {
    /// Bridges SwiftUI lifecycle to AppKit so the tracker starts at launch.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Provides the Settings scene while AppKit owns the static menu-bar item.
    var body: some Scene {
        Settings {
            KkachiLocalizedRoot(store: appDelegate.settingsStore) {
                SettingsView(store: appDelegate.settingsStore)
            }
        }
    }
}
