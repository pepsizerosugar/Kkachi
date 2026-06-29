import XCTest

/// Verifies source-level architecture rules that contributors can run locally.
final class KkachiArchitectureGuardrailTests: XCTestCase {
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testCodeFilesStayWithinLengthLimit() throws {
        let checkedExtensions: Set<String> = ["swift", "py", "js", "jsx", "ts", "tsx", "html"]
        let ignoredDirectories: Set<String> = ["PerformanceReports", ".git", "DerivedData"]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: projectRoot, includingPropertiesForKeys: [.isDirectoryKey]))
        var violations: [String] = []

        for case let fileURL as URL in enumerator {
            if ignoredDirectories.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard checkedExtensions.contains(fileURL.pathExtension) else { continue }
            let lineCount = try String(contentsOf: fileURL).split(separator: "\n", omittingEmptySubsequences: false).count
            if lineCount > 200 {
                violations.append(relativePath(for: fileURL, lineCount: lineCount))
            }
        }

        XCTAssertTrue(violations.isEmpty, "Files over 200 lines:\n\(violations.sorted().joined(separator: "\n"))")
    }

    func testDomainDoesNotImportPlatformFrameworks() throws {
        let forbiddenImports = ["AppKit", "SwiftUI", "ServiceManagement", "ScriptingBridge", "UserNotifications", "OSLog"]
        let domainRoot = projectRoot.appendingPathComponent("Kkachi/Domain")
        var violations: [String] = []

        for fileURL in try swiftFiles(under: domainRoot) {
            let source = try String(contentsOf: fileURL)
            for framework in forbiddenImports where source.contains("\nimport \(framework)") || source.hasPrefix("import \(framework)") {
                violations.append("\(relativePath(for: fileURL)): \(framework)")
            }
        }

        XCTAssertTrue(violations.isEmpty, "Domain imports platform frameworks:\n\(violations.sorted().joined(separator: "\n"))")
    }

    func testDomainDoesNotReferenceInfrastructureConcreteTypes() throws {
        let forbiddenTokens = [
            "BrowserRegistry",
            "WorkspaceApplicationOpener",
            "SystemPasteboardWriter",
            "SystemLoginItemService",
            "SystemWorkspaceNotifications",
            "PruneNotifier",
            "AppleScriptBridge",
            "BrowserScriptingBridge",
            "RestoreHistoryStore"
        ]
        let domainRoot = projectRoot.appendingPathComponent("Kkachi/Domain")

        let violations = try sourceViolations(under: domainRoot, forbiddenTokens: forbiddenTokens)

        XCTAssertTrue(violations.isEmpty, "Domain references infrastructure concrete types:\n\(violations.sorted().joined(separator: "\n"))")
    }

    func testUIDoesNotReferenceAutomationInfrastructure() throws {
        let forbiddenTokens = [
            "ScriptingBridge",
            "ServiceManagement",
            "UserNotifications",
            "AppleScriptBridge",
            "BrowserScriptingBridge",
            "SystemLoginItemService",
            "PruneNotifier"
        ]
        let uiRoot = projectRoot.appendingPathComponent("Kkachi/UI")

        let violations = try sourceViolations(under: uiRoot, forbiddenTokens: forbiddenTokens)

        XCTAssertTrue(violations.isEmpty, "UI references automation or platform infrastructure:\n\(violations.sorted().joined(separator: "\n"))")
    }

    private func sourceViolations(under root: URL, forbiddenTokens: [String]) throws -> [String] {
        try swiftFiles(under: root).flatMap { fileURL in
            let source = try String(contentsOf: fileURL)
            return forbiddenTokens.compactMap { token in
                source.contains(token) ? "\(relativePath(for: fileURL)): \(token)" : nil
            }
        }
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return enumerator.compactMap { item in
            guard let fileURL = item as? URL, fileURL.pathExtension == "swift" else { return nil }
            return fileURL
        }
    }

    private func relativePath(for fileURL: URL, lineCount: Int) -> String {
        "\(fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")): \(lineCount)"
    }

    private func relativePath(for fileURL: URL) -> String {
        fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
    }
}
