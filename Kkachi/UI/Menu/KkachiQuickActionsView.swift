import SwiftUI

/// Shows the single command that should receive first-screen attention.
struct KkachiQuickActionsView: View {
    /// Routes action taps through the app store so UI remains thin.
    @ObservedObject var store: KkachiStore

    /// Renders exactly one prominent action so the status menu stays decisive.
    var body: some View {
        primaryButton(for: snapshot.primaryAction)
    }

    /// Provides the current action model for the home menu.
    private var snapshot: KkachiMenuHomeSnapshot {
        store.menuHomeSnapshot
    }

    /// Renders the highest-priority command with text for immediate comprehension. Return activates it
    /// without needing focus, since the menu always has exactly one primary action.
    @ViewBuilder
    private func primaryButton(for action: KkachiHomeAction) -> some View {
        baseButton(for: action)
            .buttonStyle(KkachiPrimaryActionButtonStyle(accentColor: accentColor(for: action), isProminent: action != .pause))
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("menu.primaryAction.\(identifier(for: action))")
    }

    /// Gives restore its own fill while setup and pruning follow state severity. Uses the prominent
    /// fill family (not the glyph tone) so white button text always clears WCAG AA.
    private func accentColor(for action: KkachiHomeAction) -> Color {
        action == .undoLastPrune ? KkachiMenuPalette.attentionFill : snapshot.tone.prominentFillColor
    }

    /// Builds the shared primary action content before choosing emphasis.
    @ViewBuilder
    private func baseButton(for action: KkachiHomeAction) -> some View {
        if action == .openSettings {
            SettingsSceneLink {
                primaryActionLabel(for: action)
            }
            .help(Text(LocalizedStringKey(action.helpKey)))
            .accessibilityHint(Text(LocalizedStringKey(action.helpKey)))
        } else {
            Button {
                perform(action)
            } label: {
                primaryActionLabel(for: action)
            }
            .help(Text(LocalizedStringKey(action.helpKey)))
            .accessibilityHint(Text(LocalizedStringKey(action.helpKey)))
        }
    }

    /// Renders consistent text and icon content across buttons and SettingsLink.
    private func primaryActionLabel(for action: KkachiHomeAction) -> some View {
        Label(LocalizedStringKey(action.labelKey), systemImage: action.symbolName)
            .frame(maxWidth: .infinity)
    }

    /// Executes one home command while preserving browser and pruning safety rules.
    private func perform(_ action: KkachiHomeAction) {
        switch action {
        case .reviewQueue:
            revealFirstAtRiskTab()
        case .undoLastPrune:
            store.restoreLastPrunedTab()
        case .pause:
            store.setPaused(true)
        case .resume:
            store.setPaused(false)
        case .openBrowser:
            store.openPrimaryBrowser()
        case .retry:
            store.refreshPermissionState()
        case .openSettings:
            // SettingsSceneLink handles this case before button actions reach the store.
            break
        case .connect:
            store.connect()
        }
    }

    /// Reveals the next risky tab instead of navigating inside the tiny menu.
    private func revealFirstAtRiskTab() {
        guard let tab = store.atRiskTabs.first else { return }

        store.reveal(tab)
    }

    /// Provides a stable nonlocalized identifier for UI automation.
    private func identifier(for action: KkachiHomeAction) -> String {
        switch action {
        case .reviewQueue:
            return "reviewQueue"
        case .undoLastPrune:
            return "undoLastPrune"
        case .pause:
            return "pause"
        case .resume:
            return "resume"
        case .openBrowser:
            return "openBrowser"
        case .retry:
            return "retry"
        case .openSettings:
            return "openSettings"
        case .connect:
            return "connect"
        }
    }
}
