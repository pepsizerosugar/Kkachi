import XCTest

/// Verifies automatic prune and restore behavior through the running app.
final class KkachiUITabLifecycleTests: KkachiUITestCase {
    /// Verifies an expired browser tab is closed and then reopened via undo.
    func testExpiredTabIsPrunedAndRestoredThroughApp() {
        let app = launch(surface: "menu", scenario: "expired")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.browser.closedCount", "1", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.openTabs", "0", in: app))
        XCTAssertTrue(waitForState("uiTest.state.historyCount", "1", in: app))
        XCTAssertTrue(element("menu.history.undoLast", in: app).waitForExistence(timeout: timeout))

        element("menu.history.undoLast", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.restoredCount", "1", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.openTabs", "1", in: app))
    }

    /// Verifies expired audible media is protected from automatic pruning.
    func testPlayingMediaTabIsNotPrunedThroughApp() {
        let app = launch(surface: "menu", scenario: "mediaPlaying")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.browser.closedCount", "0", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.openTabs", "1", in: app))
        XCTAssertTrue(waitForState("uiTest.state.historyCount", "0", in: app))
        XCTAssertTrue(waitForState("uiTest.state.atRiskCount", "0", in: app))
        XCTAssertFalse(element("menu.context.queue", in: app).exists)
    }

    /// Verifies unverifiable media state blocks automatic close and surfaces review context.
    func testUnavailableMediaStateShowsBlockedQueue() {
        let app = launch(surface: "menu", scenario: "mediaUnavailable")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.browser.closedCount", "0", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.openTabs", "1", in: app))
        XCTAssertTrue(waitForState("uiTest.state.historyCount", "0", in: app))
        XCTAssertTrue(waitForState("uiTest.state.blockedCount", "1", in: app))
        XCTAssertTrue(element("menu.context.queue", in: app).exists)
        XCTAssertTrue(element("menu.atRisk.blocked", in: app).exists)
    }
}
