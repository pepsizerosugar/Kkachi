import XCTest
@testable import Kkachi

/// Verifies source release metadata that is easy to regress outside app code.
final class KkachiReleaseConfigurationTests: XCTestCase {
    /// Ensures the app ships as a non-sandboxed, hardened-runtime utility that can still send browser
    /// Apple Events — the direct Developer-ID distribution path, not the App Store sandbox.
    func testEntitlementsEnableDirectDistributionAutomation() throws {
        let entitlements = try propertyList(named: "Kkachi/Resources/Kkachi.entitlements")

        XCTAssertEqual(entitlements["com.apple.security.automation.apple-events"] as? Bool, true)
        XCTAssertNil(entitlements["com.apple.security.app-sandbox"], "direct distribution is non-sandboxed")
        XCTAssertNil(entitlements["com.apple.security.temporary-exception.apple-events"])
    }

    /// Ensures the app remains a menu-bar utility with the required privacy copy.
    func testInfoPlistKeepsMenuBarAndAutomationPrivacyMetadata() throws {
        let infoPlist = try propertyList(named: "Kkachi/Resources/Info.plist")
        let appleEventsCopy = try XCTUnwrap(infoPlist["NSAppleEventsUsageDescription"] as? String)

        XCTAssertEqual(infoPlist["LSUIElement"] as? Bool, true)
        XCTAssertEqual(infoPlist["CFBundleName"] as? String, "$(PRODUCT_NAME)")
        XCTAssertTrue(appleEventsCopy.contains("Kkachi"))
        XCTAssertTrue(appleEventsCopy.contains("page content"))
    }

    /// Ensures App Store and menu-bar icon assets keep their required renditions.
    func testIconAssetCatalogsKeepReleaseRenditions() throws {
        let appIconFiles = try assetFiles(named: "AppIcon.appiconset")
        let menuBarIconFiles = try assetFiles(named: "MenuBarIcon.imageset")

        XCTAssertEqual(appIconFiles.count, 10)
        XCTAssertTrue(appIconFiles.contains("icon_512x512@2x.png"))
        XCTAssertEqual(menuBarIconFiles, Set(["menubar_icon.png", "menubar_icon@2x.png", "menubar_icon@3x.png"]))
    }

    /// Returns the repository root based on this test file's source path.
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Loads a source property list dictionary for release metadata assertions.
    private func propertyList(named path: String) throws -> [String: Any] {
        let url = projectRoot.appendingPathComponent(path)
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(object as? [String: Any])
    }

    /// Loads filenames from a source asset catalog and verifies each file exists.
    private func assetFiles(named catalogName: String) throws -> Set<String> {
        let catalogURL = projectRoot.appendingPathComponent("Kkachi/Resources/Assets.xcassets").appendingPathComponent(catalogName)
        let contentsURL = catalogURL.appendingPathComponent("Contents.json")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: contentsURL)) as? [String: Any]
        let images = try XCTUnwrap(catalog?["images"] as? [[String: Any]])
        let filenames = Set(images.compactMap { $0["filename"] as? String })

        for filename in filenames {
            let imageURL = catalogURL.appendingPathComponent(filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path), filename)
        }

        return filenames
    }
}
