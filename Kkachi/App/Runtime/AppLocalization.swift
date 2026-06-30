import Foundation

/// Resolves localized strings through Kkachi's app-language preference instead of only system locale.
enum AppLocalization {
    /// Returns the display bundle that matches the selected language, falling back to system lookup.
    static func bundle(for language: AppLanguage) -> Bundle {
        guard let lprojName = language.lprojName,
              let url = Bundle.main.url(forResource: lprojName, withExtension: "lproj"),
              let bundle = Bundle(url: url)
        else {
            return .main
        }
        return bundle
    }

    /// Looks up one key in the selected app language.
    static func string(_ key: String, language: AppLanguage) -> String {
        bundle(for: language).localizedString(forKey: key, value: nil, table: nil)
    }

    /// Formats a localized string using the selected language's numeric and punctuation conventions.
    static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: string(key, language: language), locale: language.formattingLocale, arguments: arguments)
    }
}
