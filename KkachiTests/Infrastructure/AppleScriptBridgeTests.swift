import Foundation
import XCTest
@testable import Kkachi

/// Verifies AppleScript fallback parsing without automating real browsers.
final class AppleScriptBridgeTests: XCTestCase {
    /// Ensures nested AppleEvent rows become stable Chromium tab snapshots.
    func testChromiumSnapshotParsingUsesNestedRows() throws {
        let descriptor = BrowserDescriptor(
            id: "whale",
            bundleIdentifier: "com.naver.Whale",
            appleScriptName: "Whale",
            displayNameKey: "browser.whale",
            applicationPath: "/Applications/Whale.app",
            family: .chromium,
            capabilities: .chromium
        )
        let result = NSAppleEventDescriptor.list()
        result.insert(Self.row(windowID: "10", tabID: "20", activeTabID: "21", url: "https://example.com/a", title: "A"), at: 1)
        result.insert(Self.row(windowID: "10", tabID: "21", activeTabID: "21", url: "https://example.com/b", title: "B"), at: 2)

        let snapshots = try AppleScriptBridge.chromiumSnapshots(from: result, descriptor: descriptor, operation: "test")

        XCTAssertEqual(snapshots.map(\.identity.stableID), ["whale:10:20", "whale:10:21"])
        XCTAssertEqual(snapshots.map(\.isActive), [false, true])
        XCTAssertEqual(snapshots.map(\.url.absoluteString), ["https://example.com/a", "https://example.com/b"])
    }

    /// Guards the recurring "restored tab opens as a file" bug: restore must hand Launch Services the
    /// saved web URL untouched — same scheme, host, path, and query — never a coerced `file://` URL.
    func testRestoreOpenItemsKeepsQueryURLAsWebAddress() throws {
        let url = try XCTUnwrap(URL(string: "https://gall.dcinside.com/mgallery/board/view/?id=obsstudio&no=2873"))
        let tab = PrunedTab(
            id: UUID(),
            url: url,
            title: "DCInside",
            prunedAt: Date(timeIntervalSince1970: 0),
            batchID: UUID(),
            browserID: "whale",
            browserNameKey: "browser.whale",
            originalIdentity: nil
        )

        let items = BrowserScriptingBridge.restoreOpenItems(for: tab)

        XCTAssertEqual(items, [url])
        XCTAssertEqual(items.first?.scheme, "https")
        XCTAssertEqual(items.first?.absoluteString, "https://gall.dcinside.com/mgallery/board/view/?id=obsstudio&no=2873")
        XCTAssertFalse(items.first?.isFileURL ?? true)
    }

    /// Ensures scripts are escaped before Swift values enter AppleScript source.
    func testAppleScriptStringEscaping() {
        let escaped = AppleScriptBridge.quotedAppleScriptString("a \"quote\" \\ path\nnext")

        XCTAssertEqual(escaped, "\"a \\\"quote\\\" \\\\ path\\nnext\"")
    }

    /// Creates one AppleEvent row matching {windowID, tabID, activeTabID, URL, title}.
    private static func row(
        windowID: String,
        tabID: String,
        activeTabID: String,
        url: String,
        title: String
    ) -> NSAppleEventDescriptor {
        let row = NSAppleEventDescriptor.list()
        row.insert(NSAppleEventDescriptor(string: windowID), at: 1)
        row.insert(NSAppleEventDescriptor(string: tabID), at: 2)
        row.insert(NSAppleEventDescriptor(string: activeTabID), at: 3)
        row.insert(NSAppleEventDescriptor(string: url), at: 4)
        row.insert(NSAppleEventDescriptor(string: title), at: 5)
        return row
    }
}
