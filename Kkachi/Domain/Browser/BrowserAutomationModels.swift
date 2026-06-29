import Foundation

/// Describes browser automation failures with operation context while keeping domain code off bridge types.
enum BrowserAutomationError: Error, Equatable {
    case executionFailed(operation: String, details: String)
}

/// Tracks whether a browser capability has been verified without conflating setup causes.
enum BrowserCapabilityState: Equatable {
    /// Indicates Kkachi has not yet proven this capability in the current environment.
    case unknown

    /// Indicates the capability succeeded during probing or polling.
    case ready

    /// Indicates macOS or the browser denied the capability.
    case denied
}

/// Explains why a close request was intentionally skipped instead of failing.
enum BrowserTabCloseSkipReason: Equatable {
    /// Protects Safari tabs whose URL/title fingerprint is duplicated.
    case ambiguousIdentity

    /// Protects tabs whose current URL/title no longer matches the last snapshot.
    case identityChanged
}

/// Represents the non-throwing outcome of a browser close request.
enum BrowserTabCloseResult: Equatable {
    /// Indicates the browser accepted the close command.
    case closed

    /// Indicates the adapter deliberately avoided a destructive action.
    case skipped(reason: BrowserTabCloseSkipReason)
}

/// Represents the non-throwing outcome of showing a live tab in its browser.
enum BrowserTabRevealResult: Equatable {
    /// Indicates the browser focused the requested live tab.
    case revealed

    /// Indicates the adapter deliberately avoided focusing an unsafe identity.
    case skipped(reason: BrowserTabCloseSkipReason)
}

/// Publishes one browser's setup and tracking state to the UI.
struct BrowserStatus: Identifiable, Equatable {
    /// Identifies the browser row.
    var id: BrowserID { descriptor.id }

    /// Describes the browser represented by this status.
    let descriptor: BrowserDescriptor

    /// Indicates whether the app bundle exists locally.
    let isInstalled: Bool

    /// Indicates whether the browser process is currently running.
    let isRunning: Bool

    /// Indicates whether the user policy allows tracking this browser.
    let isEnabled: Bool

    /// Stores whether Apple Events automation has been verified.
    let automationState: BrowserCapabilityState

    /// Retains the latest developer-facing error for diagnostics.
    let lastErrorDescription: String?

    /// Indicates whether automatic pruning can use browser-level Apple Events safely.
    var isEligibleForPruning: Bool {
        isInstalled && isRunning && isEnabled && automationState == .ready
    }

    /// Preserves the compact readiness state consumed by existing UI surfaces.
    var permissionState: AutomationPermissionState {
        guard isInstalled else { return .notInstalled }
        guard isEnabled else { return .disabled }
        guard isRunning else { return .browserMissing }
        if automationState == .denied { return .automationDenied }
        return isEligibleForPruning ? .ready : .unknown
    }
}

/// Abstracts browser automation behind testable, browser-specific adapters.
@MainActor
protocol BrowserAdapter {
    /// Describes the browser automated by this adapter.
    var descriptor: BrowserDescriptor { get }

    /// Reports whether the browser app exists locally.
    func isInstalled() -> Bool

    /// Reports whether the browser process is currently running.
    func isRunning() -> Bool

    /// Verifies that Apple Events can reach the browser process.
    func probeAutomation() throws

    /// Fetches all open tabs with enough metadata to track inactivity.
    func fetchTabs() throws -> [BrowserTabSnapshot]

    /// Closes a tab after any adapter-specific safety validation.
    func closeTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult

    /// Brings a tracked tab forward in its owning browser for user review.
    func reveal(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult

    /// Restores a pruned tab by opening its retained URL in its browser.
    func restore(_ tab: PrunedTab) throws
}
