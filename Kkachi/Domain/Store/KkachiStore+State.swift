import Combine
import Foundation

/// Keeps store-derived state synchronized with tracker and system integrations.
@MainActor
extension KkachiStore {
    /// Refreshes browser install and running state without touching Apple Events.
    func refreshBrowserAvailability() {
        tracker.refreshBrowserStatuses(probe: false)
        permissionState = aggregatePermissionState(from: tracker.browserStatuses)
    }

    /// Probes supported browsers and Apple Events readiness for setup guidance.
    func refreshPermissionState() {
        tracker.refreshBrowserStatuses(probe: true)
        permissionState = aggregatePermissionState(from: tracker.browserStatuses)
    }

    /// Refreshes Settings from the actual OS-backed login item state.
    func refreshLoginItemState() {
        isLaunchAtLoginEnabled = loginItemService.isEnabled
    }

    /// Updates whether a close cycle posts its "Closed N tabs" notification. Pure preference write — it
    /// does not touch polling, so no policy re-apply is needed.
    func setNotifyOnPrune(_ isEnabled: Bool) {
        preferences.setNotifyOnPrune(isEnabled)
    }

    /// Deep-links to System Settings > Privacy & Security > Automation so a denied user can grant
    /// access in one tap instead of hunting through panes.
    func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        applicationOpener.openURL(url)
    }

    /// Connects nested observable objects to this store's SwiftUI invalidation.
    func bindNestedChanges() {
        tracker.$status.sink { [weak self] status in
            self?.synchronizePermissionState(for: status)
        }
        .store(in: &cancellables)

        tracker.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)

        preferences.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }

    /// Keeps permission state aligned with tracker lifecycle changes.
    private func synchronizePermissionState(for status: TrackerStatus) {
        switch status {
        case .running:
            permissionState = aggregatePermissionState(from: tracker.browserStatuses)
        case .waitingForBrowser:
            permissionState = aggregatePermissionState(from: tracker.browserStatuses)
        case .automationError:
            permissionState = visiblePermissionState
        case .pausedByUser, .pausedForSleep:
            break
        }
    }

    /// Collapses browser-specific states into the compact menu permission card state.
    private func aggregatePermissionState(from statuses: [BrowserStatus]) -> AutomationPermissionState {
        if statuses.contains(where: { $0.permissionState == .ready }) { return .ready }
        if statuses.allSatisfy({ $0.permissionState == .notInstalled }) { return .notInstalled }
        if statuses.contains(where: { $0.permissionState == .automationDenied }) { return .automationDenied }
        if statuses.contains(where: { $0.permissionState == .browserMissing }) { return .browserMissing }
        if statuses.allSatisfy({ $0.permissionState == .disabled }) { return .disabled }
        return .unknown
    }
}
