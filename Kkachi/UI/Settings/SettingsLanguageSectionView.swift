import SwiftUI

/// Lets users override Kkachi's display language without leaving Settings.
struct SettingsLanguageSectionView: View {
    /// Shared store whose preference write triggers immediate locale redraws.
    @ObservedObject var store: KkachiStore

    /// Renders one compact language picker in the Settings form.
    var body: some View {
        Section("settings.language.section") {
            Picker("settings.language.title", selection: languageBinding) {
                ForEach(AppLanguage.allCases) { language in
                    Text(LocalizedStringKey(language.localizationKey))
                        .tag(language)
                        .accessibilityIdentifier(identifier(for: language))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings.language")
        }
    }

    /// Bridges the picker to the persisted preference.
    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { store.preferences.appLanguage },
            set: { store.setAppLanguage($0) }
        )
    }

    /// Builds stable UI-test identifiers without adding fake localization keys to source scans.
    private func identifier(for language: AppLanguage) -> String {
        ["settings", "language", language.accessibilitySuffix].joined(separator: ".")
    }
}
