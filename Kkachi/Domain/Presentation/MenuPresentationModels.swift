import Foundation

/// Describes the visual urgency of the menu without importing SwiftUI into domain code.
enum MenuTone: Equatable {
    /// Indicates background pruning is healthy and quiet.
    case steady

    /// Indicates tabs need user review soon.
    case attention

    /// Indicates setup is incomplete but recoverable.
    case warning

    /// Indicates automation failed and needs direct user action.
    case critical

    /// Indicates pruning is intentionally or externally paused.
    case idle
}

/// Describes the one primary setup or recovery command shown in the menu.
enum MenuPrimaryAction: Equatable {
    /// Opens an installed supported browser when no running browser is available.
    case openBrowser

    /// Re-runs browser automation readiness probes.
    case retry

    /// Opens Settings when the user disabled all relevant automation.
    case openSettings

    /// Resumes pruning after the user paused it.
    case resume

    /// Selects an SF Symbol that makes the command recognizable without extra text.
    var symbolName: String {
        switch self {
        case .openBrowser:
            return "globe"
        case .retry:
            return "arrow.clockwise"
        case .openSettings:
            return "gearshape"
        case .resume:
            return "play.fill"
        }
    }
}

/// Provides a UI-ready summary so views do not duplicate product-state decisions.
struct MenuPresentationState: Equatable {
    /// Points to the localized headline shown at the top of the menu.
    let headlineKey: String

    /// Points to the localized short explanation below the headline.
    let detailKey: String

    /// Supplies the count to interpolate into a count-bearing headline (the at-risk state names how many
    /// tabs close soon), or nil when the headline is a static key. The hero formats with String(format:)
    /// only when this is set, so the headline catalog value must include a %lld for counted states.
    let headlineCount: Int?

    /// Chooses the semantic visual treatment for the headline and card.
    let tone: MenuTone

    /// Stores the single primary action, if the current state needs one.
    let primaryAction: MenuPrimaryAction?

    /// Counts browsers fully eligible for pruning.
    let readyBrowserCount: Int

    /// Counts enabled browsers that need setup or permission attention.
    let issueBrowserCount: Int

    /// Indicates whether browser details should be expanded by default.
    let shouldExpandBrowserDetails: Bool

    /// Indicates whether setup or permission recovery needs an explanatory context card.
    let shouldShowRecoveryCard: Bool
}

/// Builds menu presentation state from tracker and permission facts.
extension MenuPresentationState {
    /// Creates the state used by the dashboard for hierarchy and primary action.
    static func make(status: TrackerStatus, permission: AutomationPermissionState, summary: TrackingSummary, browserStatuses: [BrowserStatus], isPaused: Bool) -> MenuPresentationState {
        let readyCount = browserStatuses.filter(\.isEligibleForPruning).count
        let issueCount = browserStatuses.filter(Self.needsAttention).count
        if isPaused || status == .pausedByUser {
            return makePaused(readyCount: readyCount, issueCount: issueCount)
        }
        if status == .pausedForSleep {
            return makeSleeping(readyCount: readyCount, issueCount: issueCount)
        }
        if status == .automationError || permission == .automationDenied {
            return makeProblem(permission: permission, readyCount: readyCount, issueCount: issueCount)
        }
        if permission != .ready {
            return makeSetup(permission: permission, readyCount: readyCount, issueCount: issueCount)
        }
        if summary.atRiskCount > 0 {
            return makeAttention(atRiskCount: summary.atRiskCount, readyCount: readyCount, issueCount: issueCount)
        }
        if summary.blockedCount > 0 {
            return makeBlockedTabs(blockedCount: summary.blockedCount, readyCount: readyCount, issueCount: issueCount)
        }
        return makeReady(scannedCount: summary.scannedCount, readyCount: readyCount, issueCount: issueCount)
    }

    /// Returns true when a browser row should be elevated in the details section.
    private static func needsAttention(_ status: BrowserStatus) -> Bool {
        guard status.isEnabled else { return false }
        switch status.permissionState {
        case .automationDenied:
            return true
        case .browserMissing:
            return status.isInstalled
        case .unknown:
            return status.isInstalled && status.isRunning
        case .ready, .notInstalled, .disabled:
            return false
        }
    }

    /// Builds the quiet healthy state for normal background pruning. When nothing is being scanned yet
    /// (browser open with only active tabs, or none eligible), the detail says so plainly instead of
    /// claiming tabs are "being watched quietly" — keeping the loudest hero text truthful.
    private static func makeReady(scannedCount: Int, readyCount: Int, issueCount: Int) -> MenuPresentationState {
        let detail = scannedCount > 0 ? "menu.overview.detail.ready" : "menu.overview.detail.ready.idle"
        return MenuPresentationState(headlineKey: "menu.overview.headline.ready", detailKey: detail, headlineCount: nil, tone: .steady, primaryAction: nil, readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: issueCount > 0, shouldShowRecoveryCard: false)
    }

    /// Builds the honest sleep state for when macOS sleep has suspended polling: idle tone, no Resume
    /// action (it auto-resumes on wake), so the hero never claims active monitoring while suspended.
    private static func makeSleeping(readyCount: Int, issueCount: Int) -> MenuPresentationState {
        MenuPresentationState(headlineKey: "menu.overview.headline.sleeping", detailKey: "menu.overview.detail.sleeping", headlineCount: nil, tone: .idle, primaryAction: nil, readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: false, shouldShowRecoveryCard: false)
    }

    /// Builds the focused review state for soon-to-prune tabs. Carries atRiskCount so the headline can
    /// name how many tabs are closing soon instead of a vague "review" prompt that duplicates the button.
    private static func makeAttention(atRiskCount: Int, readyCount: Int, issueCount: Int) -> MenuPresentationState {
        MenuPresentationState(headlineKey: "menu.overview.headline.attention", detailKey: "menu.overview.detail.attention", headlineCount: atRiskCount, tone: .attention, primaryAction: nil, readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: issueCount > 0, shouldShowRecoveryCard: false)
    }

    /// Builds the honest state for overdue tabs Kkachi could not auto-close. It names how many need a
    /// manual close instead of promising they are about to be pruned, so the hero stays truthful when the
    /// only remaining work is tabs the user must close or protect themselves. The count-bearing headline
    /// catalog value must include a %lld.
    private static func makeBlockedTabs(blockedCount: Int, readyCount: Int, issueCount: Int) -> MenuPresentationState {
        MenuPresentationState(headlineKey: "menu.overview.headline.blocked", detailKey: "menu.overview.detail.blocked", headlineCount: blockedCount, tone: .attention, primaryAction: nil, readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: issueCount > 0, shouldShowRecoveryCard: false)
    }

    /// Builds the paused state with a direct resume command.
    private static func makePaused(readyCount: Int, issueCount: Int) -> MenuPresentationState {
        MenuPresentationState(headlineKey: "menu.overview.headline.paused", detailKey: "menu.overview.detail.paused", headlineCount: nil, tone: .idle, primaryAction: .resume, readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: issueCount > 0, shouldShowRecoveryCard: false)
    }

    /// Builds setup guidance when browser readiness is incomplete.
    private static func makeSetup(permission: AutomationPermissionState, readyCount: Int, issueCount: Int) -> MenuPresentationState {
        let headline = "menu.overview.headline.setup"
        let detail = "menu.overview.detail.setup"
        let action = action(for: permission)
        return MenuPresentationState(headlineKey: headline, detailKey: detail, headlineCount: nil, tone: .warning, primaryAction: action, readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: true, shouldShowRecoveryCard: true)
    }

    /// Builds recovery guidance after browser automation failures.
    private static func makeProblem(permission: AutomationPermissionState, readyCount: Int, issueCount: Int) -> MenuPresentationState {
        MenuPresentationState(headlineKey: "menu.overview.headline.error", detailKey: "menu.overview.detail.error", headlineCount: nil, tone: .critical, primaryAction: action(for: permission), readyBrowserCount: readyCount, issueBrowserCount: issueCount, shouldExpandBrowserDetails: true, shouldShowRecoveryCard: true)
    }

    /// Selects the single best recovery action for a compact menu surface.
    private static func action(for permission: AutomationPermissionState) -> MenuPrimaryAction {
        switch permission {
        case .browserMissing:
            return .openBrowser
        case .disabled, .notInstalled:
            return .openSettings
        case .ready:
            return .retry
        case .unknown, .automationDenied:
            return .retry
        }
    }
}
