import Foundation

/// Represents the app-level language override stored in preferences.
enum AppLanguage: String, CaseIterable, Identifiable, Equatable {
    /// Follows the user's macOS language order.
    case system

    /// Forces English UI copy.
    case english = "en"

    /// Forces Korean UI copy.
    case korean = "ko"

    /// Forces Japanese UI copy.
    case japanese = "ja"

    /// Forces Simplified Chinese UI copy.
    case simplifiedChinese = "zh-Hans"

    /// Forces Traditional Chinese UI copy.
    case traditionalChinese = "zh-Hant"

    /// Exposes the persisted raw value as stable SwiftUI identity.
    var id: String { rawValue }

    /// Points the Settings picker to localized display copy.
    var localizationKey: String {
        switch self {
        case .system:
            return "settings.language.option.system"
        case .english:
            return "settings.language.option.en"
        case .korean:
            return "settings.language.option.ko"
        case .japanese:
            return "settings.language.option.ja"
        case .simplifiedChinese:
            return "settings.language.option.zhHans"
        case .traditionalChinese:
            return "settings.language.option.zhHant"
        }
    }

    /// Selects the SwiftUI locale override; nil means the system locale remains authoritative.
    var localeIdentifier: String? {
        self == .system ? nil : rawValue
    }

    /// Names the bundled `.lproj` directory used by manual string lookup.
    var lprojName: String? {
        localeIdentifier
    }

    /// Drives Foundation formatters so interpolated values match manual language overrides.
    var formattingLocale: Locale {
        guard let identifier = localeIdentifier else { return .autoupdatingCurrent }
        return Locale(identifier: identifier)
    }

    /// Supplies a stable automation suffix without leaking localization-key shaped literals.
    var accessibilitySuffix: String {
        switch self {
        case .system: return "system"
        case .english: return "en"
        case .korean: return "ko"
        case .japanese: return "ja"
        case .simplifiedChinese: return "zhHans"
        case .traditionalChinese: return "zhHant"
        }
    }

    /// Parses persisted values while keeping bad defaults from breaking Settings on launch.
    static func storedValue(_ rawValue: String?) -> AppLanguage {
        rawValue.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }
}
