import SwiftUI

/// Composes the menu-bar dashboard for monitoring and restore workflows.
struct MenuDashboardView: View {
    /// Observes app state, preferences, and tracker summaries.
    @ObservedObject var store: KkachiStore

    /// Lays out a quiet status menu with one action and one contextual preview.
    var body: some View {
        VStack(alignment: .leading, spacing: KkachiMenuMetrics.sectionSpacing) {
            KkachiHeroView(store: store)
            // Reopen-last is already the prominent card in the restore preview below, so the standalone
            // primary button would duplicate it (and only reopens one tab, not a whole batch). Skip it in
            // that state to keep exactly one, richer reopen affordance.
            if snapshot.primaryAction != .undoLastPrune {
                KkachiQuickActionsView(store: store)
            }
            contextSection
            Divider()
            MenuFooterView(store: store)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(width: 312)
    }

    /// Provides the compact home state used to decide which details are worth showing.
    private var snapshot: KkachiMenuHomeSnapshot {
        store.menuHomeSnapshot
    }

    /// Shows one compact context section after the primary action.
    @ViewBuilder
    private var contextSection: some View {
        if snapshot.primaryAction == .connect {
            FirstRunPrimingView()
        } else if snapshot.shouldShowPermissionRecovery {
            PermissionCardView(store: store)
        } else if snapshot.shouldShowQueuePreview {
            queuePreview
        } else if snapshot.shouldShowRestorePreview {
            restorePreview
        }
    }

    /// Shows the next pruning queue as a compact preview on the home menu.
    @ViewBuilder
    private var queuePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("menu.home.section.queue", systemImage: "clock.badge.exclamationmark")
                .accessibilityIdentifier("menu.context.queue")
            AtRiskListView(store: store, rowLimit: snapshot.queuePreviewLimit)
        }
    }

    /// Shows recent restore history only when it is the most useful context.
    private var restorePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("menu.section.restore", systemImage: "arrow.uturn.backward.circle")
                .accessibilityIdentifier("menu.context.restore")
            PrunedHistoryView(store: store, rowLimit: snapshot.historyPreviewLimit)
        }
    }

    /// Renders a native-looking label for compact menu sections.
    private func sectionLabel(_ key: LocalizedStringKey, systemImage: String) -> some View {
        Label(key, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
