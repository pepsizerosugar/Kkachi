import Foundation

/// Summarizes the quiet menu-bar home without importing SwiftUI.
struct KkachiMenuHomeSnapshot: Equatable {
    /// Stores branch-mark metadata used by the hero and menu-bar item.
    let mood: KkachiMoodPresentation

    /// Points to the localized hero headline.
    let headlineKey: String

    /// Points to the localized hero detail sentence.
    let detailKey: String

    /// Carries the count for a count-bearing headline (the at-risk state), or nil for static headlines.
    /// Cleared whenever the home overrides the headline (pruned/restore) since those are not counted.
    let headlineCount: Int?

    /// Describes semantic urgency for color and action emphasis.
    let tone: MenuTone

    /// Stores the main command users should see first.
    let primaryAction: KkachiHomeAction

    /// Limits first-screen queue rows so the menu does not become a table.
    let queuePreviewLimit: Int

    /// Limits recent restore rows so undo remains the dominant history command.
    let historyPreviewLimit: Int

    /// Indicates whether setup or permission recovery should appear directly under actions.
    let shouldShowPermissionRecovery: Bool

    /// Indicates whether the queue preview should be visible on the home menu.
    let shouldShowQueuePreview: Bool

    /// Indicates whether restore history should appear as the short context section.
    let shouldShowRestorePreview: Bool

    /// Builds the home snapshot from already-derived presentation decisions. `isPruning` is the brief
    /// post-close window: while true (and history just grew) the home acknowledges the close — restore
    /// context wins over the routine queue so a multi-tab cleanup is confirmed and reopenable in place.
    static func make(
        presentation: MenuPresentationState,
        mood: KkachiMoodPresentation,
        summary: TrackingSummary,
        hasRestoreHistory: Bool,
        isPaused: Bool,
        isPruning: Bool
    ) -> KkachiMenuHomeSnapshot {
        let primaryAction = primaryAction(
            presentation: presentation,
            summary: summary,
            hasRestoreHistory: hasRestoreHistory,
            isPaused: isPaused
        )
        // User pause owns the compact home: queue and restore context would compete with Resume.
        let isPauseHome = primaryAction == .resume
        let isRecoveryVisible = !isPauseHome && presentation.shouldShowRecoveryCard
        let isPrunedAck = isPruning && hasRestoreHistory && !isRecoveryVisible
        let isQueueVisible = !isPauseHome && !isRecoveryVisible && !isPrunedAck && (summary.atRiskCount > 0 || summary.blockedCount > 0)
        let isRestoreVisible = !isPauseHome && !isRecoveryVisible && (isPrunedAck || (!isQueueVisible && hasRestoreHistory))
        return KkachiMenuHomeSnapshot(
            mood: mood,
            headlineKey: isPrunedAck ? "menu.home.headline.pruned" : headlineKey(presentation: presentation, isRestoreVisible: isRestoreVisible),
            detailKey: isPrunedAck ? "menu.home.detail.pruned" : detailKey(presentation: presentation, isRestoreVisible: isRestoreVisible),
            headlineCount: (isPrunedAck || isRestoreVisible) ? nil : presentation.headlineCount,
            tone: presentation.tone,
            primaryAction: primaryAction,
            queuePreviewLimit: 3,
            historyPreviewLimit: 3,
            shouldShowPermissionRecovery: isRecoveryVisible,
            shouldShowQueuePreview: isQueueVisible,
            shouldShowRestorePreview: isRestoreVisible
        )
    }

    /// Selects the command that best matches the current app state.
    private static func primaryAction(presentation: MenuPresentationState, summary: TrackingSummary, hasRestoreHistory: Bool, isPaused: Bool) -> KkachiHomeAction {
        if let action = presentation.primaryAction {
            return KkachiHomeAction.make(from: action)
        }
        if summary.atRiskCount > 0 || summary.blockedCount > 0 {
            return .reviewQueue
        }
        if hasRestoreHistory {
            return .undoLastPrune
        }
        return isPaused ? .resume : .pause
    }

    /// Gives restore history its own copy so reversible cleanup is not hidden behind the healthy tracking state.
    private static func headlineKey(presentation: MenuPresentationState, isRestoreVisible: Bool) -> String {
        isRestoreVisible ? "menu.home.headline.restore" : presentation.headlineKey
    }

    /// Explains local safekeeping when undo is the dominant action.
    private static func detailKey(presentation: MenuPresentationState, isRestoreVisible: Bool) -> String {
        isRestoreVisible ? "menu.home.detail.restore" : presentation.detailKey
    }

    /// Builds the calm first-run home shown before the user connects a browser: a single Connect
    /// action and priming context, with no routine status, queue, or restore noise.
    static func firstRun(mood: KkachiMoodPresentation) -> KkachiMenuHomeSnapshot {
        KkachiMenuHomeSnapshot(
            mood: mood,
            headlineKey: "menu.firstRun.headline",
            detailKey: "menu.firstRun.detail",
            headlineCount: nil,
            tone: .attention,
            primaryAction: .connect,
            queuePreviewLimit: 3,
            historyPreviewLimit: 3,
            shouldShowPermissionRecovery: false,
            shouldShowQueuePreview: false,
            shouldShowRestorePreview: false
        )
    }
}
