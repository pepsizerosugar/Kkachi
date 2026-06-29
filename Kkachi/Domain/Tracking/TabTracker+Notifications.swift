import Foundation

/// Handles AppKit workspace callbacks separately from core pruning logic.
@MainActor
extension TabTracker {
    /// Adds workspace notifications that let polling sleep when browsers or macOS sleep.
    func installObservers() {
        let source = workspaceNotifications
        source.center.addObserver(self, selector: #selector(handleApplicationLaunch(_:)), name: source.didLaunchApplication, object: nil)
        source.center.addObserver(self, selector: #selector(handleApplicationTerminate(_:)), name: source.didTerminateApplication, object: nil)
        source.center.addObserver(self, selector: #selector(handleSystemWillSleep(_:)), name: source.willSleep, object: nil)
        source.center.addObserver(self, selector: #selector(handleSystemDidWake(_:)), name: source.didWake, object: nil)
        source.center.addObserver(self, selector: #selector(handleScreensDidSleep(_:)), name: source.screensDidSleep, object: nil)
        source.center.addObserver(self, selector: #selector(handleScreensDidWake(_:)), name: source.screensDidWake, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePowerConditionsChanged(_:)), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePowerConditionsChanged(_:)), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }

    /// Resumes polling when a supported browser launches after Kkachi starts.
    @objc
    func handleApplicationLaunch(_ notification: Notification) {
        guard isSupportedBrowserNotification(notification) else { return }

        isSystemSleeping = false
        isDisplayAsleep = false
        applyPolicy(currentPolicy, pollImmediately: false)
    }

    /// Pauses polling only when no supported running browser remains.
    @objc
    func handleApplicationTerminate(_ notification: Notification) {
        guard isSupportedBrowserNotification(notification) else { return }

        hasRunnableBrowser() ? applyPolicy(currentPolicy) : pauseTimer(clearState: true, statusOverride: nil)
    }

    /// Pauses polling before system sleep to avoid stale automation calls.
    @objc
    func handleSystemWillSleep(_ notification: Notification) {
        isSystemSleeping = true
        pauseTimer(clearState: false, statusOverride: .pausedForSleep)
    }

    /// Resumes polling after system wake. A system wake always wakes the display too, so this also clears
    /// the display-dormancy flag — which doubles as the recovery path if a paired screensDidWake was ever
    /// missed (macOS does not guarantee screensDidSleep/Wake pairing on external/clamshell/Sidecar setups).
    @objc
    func handleSystemDidWake(_ notification: Notification) {
        isSystemSleeping = false
        isDisplayAsleep = false
        hasRunnableBrowser() ? applyPolicy(currentPolicy) : pauseTimer(clearState: true, statusOverride: nil)
    }

    /// Pauses polling when the display sleeps: the user is away with the screen off, so there is no value
    /// in firing Apple Events at browsers. Pruning resumes on screen wake and the thresholds are
    /// time-based, so a tab that crossed its threshold while the screen slept is closed on the wake poll.
    @objc
    func handleScreensDidSleep(_ notification: Notification) {
        isDisplayAsleep = true
        pauseTimer(clearState: false, statusOverride: .pausedForSleep)
    }

    /// Resumes polling after the display wakes when a browser is runnable and the system is not itself
    /// still sleeping, mirroring `handleSystemDidWake` for the display-dormancy source.
    @objc
    func handleScreensDidWake(_ notification: Notification) {
        isDisplayAsleep = false
        guard !isSystemSleeping else { return }
        hasRunnableBrowser() ? applyPolicy(currentPolicy) : pauseTimer(clearState: true, statusOverride: nil)
    }

    /// Reschedules polling when macOS power conditions change (Low Power Mode toggled, thermal state
    /// shifted) so the Release cadence widens or tightens to match, without forcing an off-schedule poll.
    /// Unlike the NSWorkspace notifications, these default-center notifications can be delivered off the
    /// main thread, so hop to the main actor before touching the timer and @Published state.
    @objc
    func handlePowerConditionsChanged(_ notification: Notification) {
        Task { @MainActor in self.reapplyPollingCadence() }
    }

    /// Stores a developer-facing error and moves UI into a localized error state.
    func rememberAutomationError(_ error: Error) {
        lastErrorDescription = String(describing: error)
        status = .automationError
    }

    /// Returns true when a workspace notification belongs to a supported browser.
    private func isSupportedBrowserNotification(_ notification: Notification) -> Bool {
        guard let bundleID = applicationBundleID(from: notification) else { return false }

        return adapters.contains { $0.descriptor.bundleIdentifier == bundleID }
    }

    /// Extracts the launched or terminated app bundle identifier from workspace notifications.
    private func applicationBundleID(from notification: Notification) -> String? {
        workspaceNotifications.applicationBundleID(notification)
    }
}
