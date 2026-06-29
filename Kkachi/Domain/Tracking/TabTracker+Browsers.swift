import Foundation

/// Handles browser eligibility, status rows, and automation error mapping.
@MainActor
extension TabTracker {
    /// Probes all supported browsers and refreshes visible readiness rows.
    func refreshBrowserStatuses(probe: Bool) {
        KkachiDebugLog.browser("refresh statuses probe=\(probe) adapterCount=\(adapters.count)")
        browserStatuses = adapters.map { status(for: $0, probe: probe) }
    }

    /// Returns true when at least one enabled browser is installed and running.
    func hasRunnableBrowser() -> Bool {
        !runnableAdapters().isEmpty
    }

    /// Returns adapters eligible for polling under the current policy.
    func runnableAdapters() -> [any BrowserAdapter] {
        adapters.filter { adapter in
            let status = browserStatuses.first { $0.id == adapter.descriptor.id }
            let hasDeniedAutomation = status?.automationState == .denied
            let isEnabled = currentPolicy.isBrowserEnabled(adapter.descriptor.id)
            let isInstalled = adapter.isInstalled()
            let isRunning = adapter.isRunning()
            let isRunnable = isEnabled && isInstalled && isRunning && !hasDeniedAutomation
            KkachiDebugLog.browser("runnable check browser=\(adapter.descriptor.id.rawValue) enabled=\(isEnabled) installed=\(isInstalled) running=\(isRunning) automationDenied=\(hasDeniedAutomation) runnable=\(isRunnable)")
            return isRunnable
        }
    }

    /// Updates one browser row after polling or restore work. Callers that already know the install and
    /// run state (a successful poll fetch implies both) pass them in to skip a redundant FileManager and
    /// Launch Services lookup; everyone else lets it recompute by leaving them nil.
    func updateStatus(for adapter: any BrowserAdapter, automationState: BrowserCapabilityState?, error: Error?, installed: Bool? = nil, running: Bool? = nil) {
        let previous = browserStatuses.first { $0.id == adapter.descriptor.id }
        let nextStatus = makeStatus(
            adapter,
            installed: installed ?? adapter.isInstalled(),
            running: running ?? adapter.isRunning(),
            enabled: currentPolicy.isBrowserEnabled(adapter.descriptor.id),
            automationState: automationState ?? previous?.automationState ?? .unknown,
            errorDescription: error.map { String(describing: $0) }
        )
        if let index = browserStatuses.firstIndex(where: { $0.id == adapter.descriptor.id }) {
            browserStatuses[index] = nextStatus
        } else {
            browserStatuses.append(nextStatus)
        }
        KkachiDebugLog.browser("status update browser=\(adapter.descriptor.id.rawValue) installed=\(nextStatus.isInstalled) running=\(nextStatus.isRunning) enabled=\(nextStatus.isEnabled) automation=\(nextStatus.automationState) eligible=\(nextStatus.isEligibleForPruning) error=\(nextStatus.lastErrorDescription ?? "nil")")
    }

    /// Builds a browser status row and optionally probes automation.
    private func status(for adapter: any BrowserAdapter, probe: Bool) -> BrowserStatus {
        let isInstalled = adapter.isInstalled()
        let isRunning = adapter.isRunning()
        let isEnabled = currentPolicy.isBrowserEnabled(adapter.descriptor.id)
        let previousStatus = browserStatuses.first { $0.id == adapter.descriptor.id }
        let previousError = previousStatus?.lastErrorDescription
        let previousAutomation = previousStatus?.automationState ?? .unknown

        guard isInstalled else {
            KkachiDebugLog.browser("status browser=\(adapter.descriptor.id.rawValue) installed=false path=\(adapter.descriptor.applicationPath)")
            return makeStatus(adapter, installed: false, running: false, enabled: isEnabled, automationState: .unknown, errorDescription: nil)
        }
        guard isEnabled else {
            KkachiDebugLog.browser("status browser=\(adapter.descriptor.id.rawValue) enabled=false running=\(isRunning)")
            return makeStatus(adapter, installed: isInstalled, running: isRunning, enabled: false, automationState: previousAutomation, errorDescription: nil)
        }
        guard isRunning else {
            KkachiDebugLog.browser("status browser=\(adapter.descriptor.id.rawValue) running=false bundle=\(adapter.descriptor.bundleIdentifier)")
            return makeStatus(adapter, installed: isInstalled, running: false, enabled: true, automationState: previousAutomation, errorDescription: nil)
        }
        guard probe else {
            KkachiDebugLog.browser("status browser=\(adapter.descriptor.id.rawValue) probe=false automation=\(previousAutomation)")
            return makeStatus(adapter, installed: true, running: true, enabled: true, automationState: previousAutomation, errorDescription: previousError)
        }

        do {
            try adapter.probeAutomation()
        } catch {
            KkachiDebugLog.browser("probe failed browser=\(adapter.descriptor.id.rawValue) error=\(String(describing: error))")
            return makeStatus(adapter, installed: true, running: true, enabled: true, automationState: automationFailureState(for: error), errorDescription: String(describing: error))
        }

        KkachiDebugLog.browser("probe success browser=\(adapter.descriptor.id.rawValue)")
        return makeStatus(adapter, installed: true, running: true, enabled: true, automationState: .ready, errorDescription: nil)
    }

    /// Classifies automation failures so transient browser errors do not block future retries.
    func automationFailureState(for error: Error) -> BrowserCapabilityState {
        let isDenied = isAutomationPermissionDenied(error)
        KkachiDebugLog.browser("automation failure classified denied=\(isDenied) error=\(String(describing: error))")
        return isDenied ? .denied : .unknown
    }

    /// Creates one immutable browser status value.
    private func makeStatus(_ adapter: any BrowserAdapter, installed: Bool, running: Bool, enabled: Bool, automationState: BrowserCapabilityState, errorDescription: String?) -> BrowserStatus {
        BrowserStatus(
            descriptor: adapter.descriptor,
            isInstalled: installed,
            isRunning: running,
            isEnabled: enabled,
            automationState: automationState,
            lastErrorDescription: errorDescription
        )
    }

    /// Returns true only for failures that mean macOS automation permission is actually blocked.
    private func isAutomationPermissionDenied(_ error: Error) -> Bool {
        guard case let BrowserAutomationError.executionFailed(_, details) = error else { return false }
        let normalizedDetails = details.lowercased()
        return normalizedDetails.contains("-1743")
            || normalizedDetails.contains("denied")
            || normalizedDetails.contains("not authorized")
            || normalizedDetails.contains("not permitted")
            || normalizedDetails.contains("not allowed")
    }
}
