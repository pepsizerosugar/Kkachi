import Foundation

/// Formats repeated menu row strings while keeping localization calls outside view layout code.
enum KkachiMenuRowText {
    /// Returns the page title, falling back to a recognizable URL label for untitled pages.
    static func title(title rawTitle: String, url: URL) -> String {
        let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? subtitle(url: url) : trimmedTitle
    }

    /// Returns the compact URL label preferred by list rows.
    static func subtitle(url: URL) -> String {
        url.host ?? url.absoluteString
    }

    /// Formats the shared overflow row count used by menu preview lists.
    static func moreCount(_ count: Int, language: AppLanguage) -> String {
        AppLocalization.format("menu.more.count", language: language, count)
    }

    /// Builds an accessibility label that names the host acted on by a repeated icon button.
    static func hostScopedLabel(_ key: String, host: String, language: AppLanguage) -> String {
        AppLocalization.format(key, language: language, host)
    }
}
