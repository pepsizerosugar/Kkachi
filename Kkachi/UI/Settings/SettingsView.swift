import SwiftUI

/// Provides native macOS settings for pruning policy and privacy controls.
struct SettingsView: View {
    /// Observes the same app store used by the menu dashboard.
    @ObservedObject var store: KkachiStore

    /// Drives the confirmation dialog that guards the destructive Clear History action.
    @State private var isConfirmingClearHistory = false

    /// Renders settings as a compact recovery-first surface for a utility app.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader
            Form {
                SettingsBrowserSectionView(store: store)
                SettingsLanguageSectionView(store: store)
                SettingsPruningSectionView(store: store)
                SettingsExclusionsSectionView(store: store)
                privacySection
            }
            .formStyle(.grouped)
            .accessibilityIdentifier("settings.form")
        }
        .padding(22)
        .frame(minWidth: 600, maxWidth: 600, minHeight: 460, idealHeight: 620, maxHeight: 900)
    }

    /// Introduces Settings with the product promise before showing controls.
    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("app.menuBar.title")
                    .font(.title3.weight(.semibold))
                Text("settings.window.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Explains the local-only data boundary without adding onboarding friction.
    private var privacySection: some View {
        Section("settings.privacy.section") {
            Text("settings.privacy.message")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("settings.privacy.clearHistory", role: .destructive) {
                isConfirmingClearHistory = true
            }
            .disabled(store.prunedTabs.isEmpty)
            .accessibilityIdentifier("settings.privacy.clearHistory")
            .confirmationDialog(
                "settings.privacy.clearHistory.confirm.title",
                isPresented: $isConfirmingClearHistory,
                titleVisibility: .visible
            ) {
                Button("settings.privacy.clearHistory.confirm.button", role: .destructive) {
                    store.clearHistory()
                }
                .accessibilityIdentifier("settings.privacy.clearHistory.confirm")
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.privacy.clearHistory.confirm.message")
            }
        }
    }
}
