import XCTest

/// Verifies source localization keys remain present and intentionally used.
final class KkachiLocalizationCatalogTests: XCTestCase {
    /// Keeps dynamically referenced SwiftUI and presentation keys in sync with the catalog.
    func testAppLocalizedKeysMatchCatalog() throws {
        let catalogKeys = try localizableCatalogKeys()
        let referencedKeys = try productionLocalizedKeyReferences()
        let missingKeys = referencedKeys.subtracting(catalogKeys)
        let unusedKeys = catalogKeys.filter { isTrackedLocalizationKey($0) }.subtracting(referencedKeys)

        XCTAssertTrue(missingKeys.isEmpty, "Missing localization keys: \(missingKeys.sorted().joined(separator: ", "))")
        XCTAssertTrue(unusedKeys.isEmpty, "Unused localization keys: \(unusedKeys.sorted().joined(separator: ", "))")
    }

    /// Returns the repository root based on this test file's source path.
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Loads all keys from the source Localizable catalog.
    private func localizableCatalogKeys() throws -> Set<String> {
        let catalogURL = projectRoot.appendingPathComponent("Kkachi/Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        let strings = try XCTUnwrap(catalog?["strings"] as? [String: Any])
        return Set(strings.keys)
    }

    /// Finds localized key literals in production Swift files.
    private func productionLocalizedKeyReferences() throws -> Set<String> {
        let sourceRoot = projectRoot.appendingPathComponent("Kkachi")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sourceRoot, includingPropertiesForKeys: nil))
        var keys: Set<String> = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL)
            keys.formUnion(localizedKeys(in: source))
        }

        return keys
    }

    /// Extracts localized keys from string literals using product-owned prefixes.
    private func localizedKeys(in source: String) -> Set<String> {
        let scannedSource = sourceRemovingAccessibilityIdentifiers(from: source)
        let pattern = #""((?:app|browser|menu|permission|settings|threshold|tracker)\.[A-Za-z0-9_.]+)""#
        let expression = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(scannedSource.startIndex..<scannedSource.endIndex, in: scannedSource)
        var keys: Set<String> = []

        for match in expression.matches(in: scannedSource, range: range) {
            let keyRange = match.range(at: 1)
            guard let range = Range(keyRange, in: scannedSource) else { continue }
            keys.insert(String(scannedSource[range]))
        }

        return keys
    }

    /// Removes stable UI-test identifiers because they are not user-facing localization keys.
    private func sourceRemovingAccessibilityIdentifiers(from source: String) -> String {
        let pattern = #"\.accessibilityIdentifier\("[^"]+"\)"#
        let expression = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.stringByReplacingMatches(in: source, range: range, withTemplate: "")
    }

    /// Ensures every catalog entry ships all five live locales, so new copy never reaches a CJK user
    /// as a raw key. This is the i18n parity guard: a key added in English only fails the build.
    func testEveryKeyShipsAllLiveLocales() throws {
        let catalogURL = projectRoot.appendingPathComponent("Kkachi/Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        let strings = try XCTUnwrap(catalog?["strings"] as? [String: Any])
        let requiredLocales = ["en", "ja", "ko", "zh-Hans", "zh-Hant"]
        var gaps: [String] = []

        for (key, value) in strings {
            let localizations = ((value as? [String: Any])?["localizations"] as? [String: Any]) ?? [:]
            let missing = requiredLocales.filter { localizations[$0] == nil }
            if !missing.isEmpty { gaps.append("\(key): missing \(missing.sorted().joined(separator: ", "))") }
        }

        XCTAssertTrue(gaps.isEmpty, "Locale parity gaps:\n\(gaps.sorted().joined(separator: "\n"))")
    }

    /// Limits dead-key detection to user-facing product copy managed by Localizable.xcstrings.
    private func isTrackedLocalizationKey(_ key: String) -> Bool {
        let prefixes = ["app.", "browser.", "menu.", "permission.", "settings.", "threshold.", "tracker."]
        return prefixes.contains { key.hasPrefix($0) }
    }
}
