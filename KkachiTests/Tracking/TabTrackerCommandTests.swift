import XCTest
@testable import Kkachi

/// Verifies user-initiated live tab commands without real browser automation.
@MainActor
final class TabTrackerCommandTests: XCTestCase {
    /// Ensures reveal commands route to the browser that owns the tracked row.
    func testRevealRoutesToOriginalBrowser() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [.sample(tabID: "9", isActive: false, descriptor: .testWhale)], descriptor: .testWhale)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())

        tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        let whaleTab = tracker.trackedTabs.first { $0.browserID == BrowserDescriptor.testWhale.id }!
        tracker.reveal(whaleTab)

        XCTAssertTrue(chrome.revealedTabs.isEmpty)
        XCTAssertEqual(whale.revealedTabs, ["1:9"])
    }

    /// Ensures ambiguous live identities are not revealed as a different tab by mistake.
    func testRevealSkipsAmbiguousIdentity() {
        let ambiguousTab = BrowserTabSnapshot.sample(isActive: false).withIdentityAmbiguity(true)
        let context = TabTrackerTestContexts.enabled(tabs: [ambiguousTab])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.reveal(context.tracker.trackedTabs[0])

        XCTAssertEqual(context.adapter.revealCallCount, 1)
        XCTAssertTrue(context.adapter.revealedTabs.isEmpty)
        XCTAssertNil(context.tracker.lastErrorDescription)
    }
}
