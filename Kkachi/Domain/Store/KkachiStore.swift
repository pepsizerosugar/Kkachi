import Combine
import Foundation

/// Presents tracker, preferences, and permission state as one UI-facing object.
@MainActor
final class KkachiStore: ObservableObject {
    /// Owns persisted policy choices shown in Settings.
    let preferences: PreferencesStore

    /// Owns pruning behavior and browser automation state.
    let tracker: TabTracker

    /// Owns the OS-backed login item integration used by Settings.
    let loginItemService: LoginItemServicing

    /// Opens external browser apps for setup recovery flows.
    let applicationOpener: any ApplicationOpening

    /// Copies fallback restore URLs without tying store logic to AppKit pasteboard APIs.
    let pasteboardWriter: any PasteboardWriting

    /// Publishes setup readiness for permission and onboarding UI.
    @Published var permissionState: AutomationPermissionState = .unknown

    /// Publishes the actual Service Management login item state.
    @Published var isLaunchAtLoginEnabled = false

    /// Publishes a localized error key when login item registration fails.
    @Published var loginItemErrorKey: String?

    /// Retains the latest login item diagnostic for contributors debugging failures.
    private(set) var loginItemErrorDescription: String?

    /// Retains nested object subscriptions for the store lifetime.
    var cancellables: Set<AnyCancellable> = []

    /// Creates the app store from collaborators assembled by the app or tests.
    init(
        preferences: PreferencesStore,
        tracker: TabTracker,
        loginItemService: LoginItemServicing,
        applicationOpener: any ApplicationOpening,
        pasteboardWriter: any PasteboardWriting
    ) {
        self.preferences = preferences
        self.tracker = tracker
        self.loginItemService = loginItemService
        self.applicationOpener = applicationOpener
        self.pasteboardWriter = pasteboardWriter
        self.isLaunchAtLoginEnabled = self.loginItemService.isEnabled
        bindNestedChanges()
    }

    var prunedTabs: [PrunedTab] {
        tracker.prunedTabs
    }

    var trackedTabs: [TrackedTab] {
        tracker.trackedTabs
    }

    var browserStatuses: [BrowserStatus] {
        tracker.browserStatuses
    }

    var summary: TrackingSummary {
        tracker.summary
    }

    var status: TrackerStatus {
        tracker.status
    }

    var atRiskTabs: [TrackedTab] {
        trackedTabs.filter(\.isAtRisk)
    }

    /// Provides the permission state that should be shown in the menu.
    var visiblePermissionState: AutomationPermissionState {
        status == .automationError ? .automationDenied : permissionState
    }

    /// Starts setup. On first run Kkachi stays quiet — no Apple Events probe, no polling — until the
    /// user taps Connect, so a fresh install is never ambushed by the system automation dialog.
    func start() {
        guard preferences.hasCompletedFirstRun else {
            refreshBrowserAvailability()
            return
        }
        refreshPermissionState()
        tracker.start()
    }

    /// Completes first-run setup from a deliberate user tap, then probes automation and begins polling.
    func connect() {
        preferences.completeFirstRun()
        refreshPermissionState()
        tracker.start()
    }

    func stop() {
        tracker.stop()
    }

    func togglePause() {
        setPaused(!preferences.policy.isPaused)
    }

    func setThreshold(_ threshold: TimeInterval) {
        preferences.setThreshold(threshold)
        tracker.applyPolicy(preferences.policy)
    }

    #if DEBUG
    func setPollingInterval(_ pollingInterval: TimeInterval) {
        preferences.setPollingInterval(pollingInterval)
        tracker.applyPolicy(preferences.policy)
    }
    #endif

    func setPaused(_ isPaused: Bool) {
        preferences.setPaused(isPaused)
        tracker.applyPolicy(preferences.policy)
    }

    @discardableResult
    func addExclusion(_ rawValue: String) -> Bool {
        let added = preferences.addExclusion(rawValue)
        if added { tracker.applyPolicy(preferences.policy) }
        return added
    }

    /// Protects a host from pruning and returns the newly created rule so the caller can offer a
    /// quick undo. Returns nil when the input is invalid or the host is already protected, so an
    /// undo can never remove a rule the user established earlier.
    @discardableResult
    func protect(_ hostSuffix: String) -> DomainExclusionRule? {
        guard let rule = DomainExclusionRule(hostSuffix), !preferences.policy.exclusions.contains(rule) else { return nil }
        preferences.addExclusion(hostSuffix)
        tracker.applyPolicy(preferences.policy)
        return rule
    }

    func reveal(_ tab: TrackedTab) {
        tracker.reveal(tab)
    }

    func removeExclusion(_ rule: DomainExclusionRule) {
        preferences.removeExclusion(rule)
        tracker.applyPolicy(preferences.policy)
    }

    /// Enables or disables one browser in the pruning policy.
    func setBrowser(_ browserID: BrowserID, enabled: Bool) {
        if enabled, browserStatuses.contains(where: { $0.id == browserID && !$0.isInstalled }) {
            return
        }
        preferences.setBrowser(browserID, enabled: enabled)
        tracker.applyPolicy(preferences.policy)
    }

    /// Applies the user's launch-at-login preference through Service Management.
    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            try loginItemService.setEnabled(isEnabled)
            refreshLoginItemState()
            loginItemErrorKey = nil
            loginItemErrorDescription = nil
        } catch {
            refreshLoginItemState()
            loginItemErrorKey = "settings.launchAtLogin.error"
            loginItemErrorDescription = String(describing: error)
        }
    }

    /// Opens the first installed supported browser that is not currently running.
    func openPrimaryBrowser() {
        guard let status = browserStatuses.first(where: { $0.isInstalled && !$0.isRunning }) ?? browserStatuses.first(where: \.isInstalled) else { return }

        applicationOpener.openApplication(at: URL(fileURLWithPath: status.descriptor.applicationPath))
    }
}
