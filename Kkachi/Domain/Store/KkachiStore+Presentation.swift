import Foundation

/// Derives UI presentation state from store dependencies without bloating the store.
@MainActor
extension KkachiStore {
    /// Provides the dashboard with a decision-complete presentation summary.
    var menuPresentationState: MenuPresentationState {
        MenuPresentationState.make(
            status: status,
            permission: visiblePermissionState,
            summary: summary,
            browserStatuses: browserStatuses,
            isPaused: preferences.policy.isPaused
        )
    }

    /// Provides the branch-mark status used by the menu bar and dashboard header.
    var kkachiMoodPresentation: KkachiMoodPresentation {
        KkachiMoodPresentation.make(
            status: status,
            permission: visiblePermissionState,
            summary: summary,
            hasRestoreHistory: !prunedTabs.isEmpty,
            isPaused: preferences.policy.isPaused,
            isPruning: isPruningInProgress
        )
    }

    /// Provides the compact menu home model used by the quiet status popover. Before the user has
    /// connected a browser, the home is a calm first-run priming state instead of routine status.
    var menuHomeSnapshot: KkachiMenuHomeSnapshot {
        guard preferences.hasCompletedFirstRun else {
            return KkachiMenuHomeSnapshot.firstRun(mood: kkachiMoodPresentation)
        }
        return KkachiMenuHomeSnapshot.make(
            presentation: menuPresentationState,
            mood: kkachiMoodPresentation,
            summary: summary,
            hasRestoreHistory: !prunedTabs.isEmpty,
            isPaused: preferences.policy.isPaused,
            isPruning: isPruningInProgress
        )
    }
}
