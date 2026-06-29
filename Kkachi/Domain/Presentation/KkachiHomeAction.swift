import Foundation

/// Describes a high-priority command shown on the compact menu home.
enum KkachiHomeAction: Hashable {
    /// Reveals the next at-risk tab so the user can review it in context.
    case reviewQueue

    /// Restores the most recently pruned tab as a fast undo.
    case undoLastPrune

    /// Pauses automatic pruning without losing tracking state.
    case pause

    /// Resumes automatic pruning after a user pause.
    case resume

    /// Opens a supported browser so Kkachi can finish setup.
    case openBrowser

    /// Re-runs browser automation readiness checks.
    case retry

    /// Opens Kkachi settings for policy or browser enablement changes.
    case openSettings

    /// Connects a browser for the first time, requesting Apple Events access on a deliberate tap.
    case connect

    /// Points to localized button copy for the command.
    var labelKey: String {
        switch self {
        case .reviewQueue:
            return "menu.home.action.review"
        case .undoLastPrune:
            return "menu.history.undoLast"
        case .pause:
            return "menu.footer.pause"
        case .resume:
            return "menu.footer.resume"
        case .openBrowser:
            return "permission.openBrowser"
        case .retry:
            return "permission.retry"
        case .openSettings:
            return "permission.openSettings"
        case .connect:
            return "menu.firstRun.connect"
        }
    }

    /// Points to localized tooltip and VoiceOver hint copy for compact icon buttons.
    var helpKey: String {
        switch self {
        case .reviewQueue:
            return "menu.home.action.review.help"
        case .undoLastPrune:
            return "menu.history.undoLast.help"
        case .pause:
            return "menu.home.action.pause.help"
        case .resume:
            return "menu.home.action.resume.help"
        case .openBrowser:
            return "permission.openBrowser"
        case .retry:
            return "permission.retry"
        case .openSettings:
            return "permission.openSettings"
        case .connect:
            return "menu.firstRun.connect.help"
        }
    }

    /// Selects an SF Symbol that remains legible in the constrained menu surface.
    var symbolName: String {
        switch self {
        case .reviewQueue:
            return "eye"
        case .undoLastPrune:
            return "arrow.uturn.backward.circle"
        case .pause:
            return "pause.fill"
        case .resume:
            return "play.fill"
        case .openBrowser:
            return "globe"
        case .retry:
            return "arrow.clockwise"
        case .openSettings:
            return "gearshape"
        case .connect:
            return "link"
        }
    }

    /// Converts existing recovery decisions into home-screen commands.
    static func make(from action: MenuPrimaryAction) -> KkachiHomeAction {
        switch action {
        case .openBrowser:
            return .openBrowser
        case .retry:
            return .retry
        case .openSettings:
            return .openSettings
        case .resume:
            return .resume
        }
    }
}
