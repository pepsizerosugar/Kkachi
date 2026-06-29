#if DEBUG
import AppKit
import SwiftUI

/// Hosts deterministic SwiftUI surfaces when XCUITest launches the app.
@MainActor
final class KkachiUITestHarness {
    /// Names the launch environment flag that enables the harness.
    static let enabledEnvironmentKey = "KKACHI_UI_TEST_MODE"

    /// Names the launch environment value that selects menu or settings.
    private static let surfaceEnvironmentKey = "KKACHI_UI_TEST_SURFACE"

    /// Names the launch environment value that selects fixture state.
    private static let scenarioEnvironmentKey = "KKACHI_UI_TEST_SCENARIO"

    /// Names the optional launch environment value that injects large tab fixtures.
    private static let tabCountEnvironmentKey = "KKACHI_UI_TEST_TAB_COUNT"

    /// Names the optional launch environment value that terminates trace runs.
    private static let autocloseEnvironmentKey = "KKACHI_UI_TEST_AUTOCLOSE_AFTER"

    /// Identifies whether the current process should bypass the menu-bar agent path.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[enabledEnvironmentKey] == "1"
    }

    /// Retains the scenario context for the lifetime of the test window.
    private let context: KkachiUITestContext

    /// Provides the deterministic store shared by harness windows and SettingsLink.
    var store: KkachiStore {
        context.store
    }

    /// Retains the AppKit window so SwiftUI content remains alive.
    private var window: NSWindow?

    /// Creates a harness using launch environment values supplied by XCUITest.
    init() {
        let environment = ProcessInfo.processInfo.environment
        let scenario = KkachiUITestScenario(rawValue: environment[Self.scenarioEnvironmentKey] ?? "") ?? .ready
        let tabCount = KkachiUITestStressFixtures.tabCount(from: environment[Self.tabCountEnvironmentKey])
        self.context = KkachiUITestFixtures.makeContext(for: scenario, tabCount: tabCount)
    }

    /// Shows the requested surface in a normal window that XCUITest can inspect.
    func start() {
        let environment = ProcessInfo.processInfo.environment
        let surface = KkachiUITestSurface(rawValue: environment[Self.surfaceEnvironmentKey] ?? "") ?? .menu
        let hostingView = NSHostingView(rootView: rootView(for: surface))
        let testWindow = NSWindow(contentRect: surface.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        testWindow.identifier = NSUserInterfaceItemIdentifier(surface.windowIdentifier)
        testWindow.title = NSLocalizedString("app.menuBar.title", comment: "")
        testWindow.contentView = hostingView
        testWindow.setFrameOrigin(origin(for: surface))
        testWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = testWindow
        scheduleAutocloseIfNeeded()
    }

    /// Places UI-test windows away from system permission panels that often appear near screen center.
    private func origin(for surface: KkachiUITestSurface) -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let x = visibleFrame.minX + 80
        let y = visibleFrame.midY - (surface.frame.height / 2)
        return NSPoint(x: x, y: max(visibleFrame.minY + 40, y))
    }

    /// Builds the requested production surface without masking child accessibility nodes.
    private func rootView(for surface: KkachiUITestSurface) -> AnyView {
        switch surface {
        case .menu:
            return wrapped(MenuDashboardView(store: store))
        case .settings:
            return wrapped(SettingsView(store: store))
        }
    }

    /// Adds the invisible state probe without changing the tested surface itself.
    private func wrapped<Content: View>(_ content: Content) -> AnyView {
        AnyView(content.overlay(alignment: .bottomTrailing) {
            KkachiUITestStateProbe(store: store, browserState: context.browserState)
        })
    }

    /// Terminates deterministic harness runs after a caller-provided delay.
    private func scheduleAutocloseIfNeeded() {
        let rawDelay = ProcessInfo.processInfo.environment[Self.autocloseEnvironmentKey]
        guard let rawDelay, let delay = TimeInterval(rawDelay) else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            NSApp.terminate(nil)
        }
    }
}

/// Selects which app surface XCUITest should render.
private enum KkachiUITestSurface: String {
    /// Shows the menu dashboard in a testable window.
    case menu

    /// Shows the settings form in a testable window.
    case settings

    /// Provides a window identifier consumed by XCUITest.
    var windowIdentifier: String {
        "uiTest.window.\(rawValue)"
    }

    /// Sizes each surface to match its production layout constraints.
    var frame: NSRect {
        switch self {
        case .menu:
            return NSRect(x: 0, y: 0, width: 420, height: 520)
        case .settings:
            return NSRect(x: 0, y: 0, width: 660, height: 700)
        }
    }
}

/// Selects deterministic product states used by UI tests.
enum KkachiUITestScenario: String {
    /// Shows quiet ready tracking with no urgent context.
    case ready

    /// Shows a near-prune queue context.
    case atRisk

    /// Shows restore history context.
    case restore

    /// Shows automation recovery context.
    case permission

    /// Shows an installed browser that is not currently running.
    case browserMissing

    /// Shows a user-disabled browser setup state.
    case disabled

    /// Shows a supported browser that is not installed locally.
    case uninstalled

    /// Starts with an expired tab that should be pruned through tracker polling.
    case expired
}
#endif
