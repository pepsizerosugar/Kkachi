#if DEBUG
import Foundation

/// Records fake browser state while exercising the real tracker command paths.
@MainActor
final class KkachiUITestBrowserState: ObservableObject {
    /// Describes the fake browser row shown in UI fixtures.
    let descriptor: BrowserDescriptor

    /// Publishes whether the fake browser is installed.
    @Published var isInstalled = true

    /// Publishes whether the fake browser is running.
    @Published var isRunning = true

    /// Publishes the fake Apple Events readiness used by permission scenarios.
    @Published var automationState: BrowserCapabilityState = .ready

    /// Publishes currently open fake tabs so prune and restore can mutate them.
    @Published var openTabs: [BrowserTabSnapshot] = []

    /// Counts close requests accepted by the fake browser.
    @Published var closedCount = 0

    /// Counts restore requests accepted by the fake browser.
    @Published var restoredCount = 0

    /// Counts reveal requests accepted by the fake browser.
    @Published var revealedCount = 0

    /// Counts automation probes sent through retry flows.
    @Published var probeCount = 0

    /// Counts setup attempts to open a browser app.
    @Published var openApplicationCount = 0

    /// Creates state for one supported browser descriptor.
    init(descriptor: BrowserDescriptor) {
        self.descriptor = descriptor
    }

    /// Removes a tab from the fake browser exactly like a successful close command.
    func close(_ tab: BrowserTabSnapshot) -> BrowserTabCloseResult {
        closedCount += 1
        openTabs.removeAll { $0.stableID == tab.stableID }
        return .closed
    }

    /// Records a reveal command without changing tab lifetime.
    func reveal(_ tab: BrowserTabSnapshot) -> BrowserTabRevealResult {
        revealedCount += 1
        return .revealed
    }

    /// Restores a pruned tab by reopening its retained URL in the fake browser.
    func restore(_ tab: PrunedTab) {
        restoredCount += 1
        let identity = BrowserTabIdentity(browserID: tab.browserID, windowID: "restored", tabID: "\(restoredCount)", windowIndex: nil, tabIndex: nil, fingerprint: BrowserTabFingerprint(url: tab.url, title: tab.title))
        let snapshot = BrowserTabSnapshot(identity: identity, url: tab.url, title: tab.title, isActive: true, browserNameKey: tab.browserNameKey)
        openTabs.append(snapshot)
    }

    /// Records a Launch Services request without opening a real browser.
    func recordOpenApplication() {
        openApplicationCount += 1
    }

}

/// Provides browser behavior for UI tests without real Apple Events.
@MainActor
final class KkachiUITestBrowserAdapter: BrowserAdapter {
    /// Stores mutable fake browser state shared with the test probe.
    private let state: KkachiUITestBrowserState

    /// Describes the fake browser row shown in UI fixtures.
    var descriptor: BrowserDescriptor { state.descriptor }

    /// Creates a fake browser adapter backed by shared state.
    init(state: KkachiUITestBrowserState) {
        self.state = state
    }

    /// Reports deterministic installation state for settings rows.
    func isInstalled() -> Bool { state.isInstalled }

    /// Reports deterministic running state for settings rows.
    func isRunning() -> Bool { state.isRunning }

    /// Records permission retry flows and throws when the scenario remains denied.
    func probeAutomation() throws {
        state.probeCount += 1
        if state.automationState == .denied {
            throw BrowserAutomationError.executionFailed(operation: "probeAutomation", details: "denied")
        }
        state.automationState = .ready
    }

    /// Returns fake live browser tabs for real tracker polling.
    func fetchTabs() throws -> [BrowserTabSnapshot] { state.openTabs }

    /// Closes one fake tab so UI tests can prove pruning removed it.
    func closeTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult {
        state.close(tab)
    }

    /// Records reveal requests from review buttons.
    func reveal(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult {
        state.reveal(tab)
    }

    /// Reopens one pruned tab in fake browser state.
    func restore(_ tab: PrunedTab) throws {
        state.restore(tab)
    }
}

/// Provides app-opening behavior for UI tests without launching real browsers.
@MainActor
struct KkachiUITestApplicationOpener: ApplicationOpening {
    /// Stores mutable fake browser state shared with the test probe.
    let state: KkachiUITestBrowserState

    /// Records the request instead of calling Launch Services.
    func openApplication(at url: URL) {
        state.recordOpenApplication()
    }

    /// Records the default-browser fallback instead of opening a real URL.
    func openURL(_ url: URL) {
        state.recordOpenApplication()
    }
}

/// Ignores pasteboard writes so UI tests never mutate the user's pasteboard.
struct KkachiUITestPasteboardWriter: PasteboardWriting {
    func copy(_ string: String) {}
}

/// Provides login-item behavior for settings UI tests.
@MainActor
final class KkachiUITestLoginItemService: LoginItemServicing {
    /// Stores the fake Service Management state used by settings toggles.
    private(set) var isEnabled = false

    /// Records toggle changes without registering a real login item.
    func setEnabled(_ isEnabled: Bool) throws {
        self.isEnabled = isEnabled
    }
}
#endif
