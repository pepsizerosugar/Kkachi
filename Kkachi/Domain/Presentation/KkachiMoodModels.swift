import Foundation

/// Describes the menu-bar branch mark that communicates Kkachi's current state. The `String` raw value
/// is the `{state}` token in the `KkachiMascot_{state}_{NN}` imageset naming, so renaming a case renames
/// the art it loads and must stay coordinated with asset-catalog imagesets.
enum KkachiMood: String, Equatable {
    /// Indicates there is nothing urgent and pruning is idle or not yet active.
    case calm

    /// Indicates Kkachi is quietly monitoring eligible tabs.
    case watching

    /// Indicates inactive tabs are close enough to pruning to deserve review.
    case alert

    /// Indicates Kkachi is actively pruning or responding to a prune command.
    case pruning

    /// Indicates automatic pruning is intentionally paused.
    case paused

    /// Indicates permissions or browser setup blocks pruning.
    case blocked

    /// Indicates recently pruned tabs are available to restore.
    case restoreAvailable
}

/// Provides localized and visual metadata for one branch-mark state.
struct KkachiMoodPresentation: Equatable {
    /// Stores the state used by the menu-bar mark and dashboard copy.
    let mood: KkachiMood

    /// Points to concise VoiceOver copy for the menu-bar status item.
    let accessibilityKey: String

    /// Selects the fallback SF Symbol used if branch-mark assets cannot load.
    let fallbackSymbolName: String

    /// Builds the mood from tracker, permission, and restore-history state.
    static func make(
        status: TrackerStatus,
        permission: AutomationPermissionState,
        summary: TrackingSummary,
        hasRestoreHistory: Bool,
        isPaused: Bool,
        isPruning: Bool
    ) -> KkachiMoodPresentation {
        let mood = resolvedMood(
            status: status,
            permission: permission,
            summary: summary,
            hasRestoreHistory: hasRestoreHistory,
            isPaused: isPaused,
            isPruning: isPruning
        )
        return KkachiMoodPresentation(
            mood: mood,
            accessibilityKey: accessibilityKey(for: mood),
            fallbackSymbolName: fallbackSymbolName(for: mood)
        )
    }

    /// Resolves product state into one status mark, ordered so the menu-bar item always reflects what
    /// Kkachi is doing NOW rather than a stale fact. Key ordering rules: a paused/sleeping or blocked
    /// state wins because nothing is being watched; a brief post-close `.pruning` gesture acknowledges
    /// the moment tabs are closed; live `.watching` outranks `.restoreAvailable` so the bird never gets
    /// frozen on "you have tabs to restore" the instant any history exists — restore stays reachable in
    /// the menu, and `.restoreAvailable` shows only while nothing is actively being watched.
    private static func resolvedMood(
        status: TrackerStatus,
        permission: AutomationPermissionState,
        summary: TrackingSummary,
        hasRestoreHistory: Bool,
        isPaused: Bool,
        isPruning: Bool
    ) -> KkachiMood {
        if isPaused || status == .pausedByUser || status == .pausedForSleep { return .paused }
        if status == .automationError || permission == .automationDenied { return .blocked }
        if permission != .ready { return .calm }
        if isPruning { return .pruning }
        if summary.atRiskCount > 0 { return .alert }
        if status == .running && summary.scannedCount > 0 { return .watching }
        if hasRestoreHistory { return .restoreAvailable }
        return .calm
    }

    /// Returns catalog-backed VoiceOver copy for one mood.
    private static func accessibilityKey(for mood: KkachiMood) -> String {
        switch mood {
        case .calm:
            return "menu.mood.calm"
        case .watching:
            return "menu.mood.watching"
        case .alert:
            return "menu.mood.alert"
        case .pruning:
            return "menu.mood.pruning"
        case .paused:
            return "menu.mood.paused"
        case .blocked:
            return "menu.mood.blocked"
        case .restoreAvailable:
            return "menu.mood.restoreAvailable"
        }
    }

    /// Returns a conservative SF Symbol when branch-mark images are unavailable.
    private static func fallbackSymbolName(for mood: KkachiMood) -> String {
        switch mood {
        case .calm, .watching:
            return "bird"
        case .alert:
            return "clock.badge.exclamationmark"
        case .pruning:
            return "archivebox"
        case .paused:
            return "pause.circle"
        case .blocked:
            return "exclamationmark.triangle"
        case .restoreAvailable:
            return "arrow.uturn.backward.circle"
        }
    }
}
