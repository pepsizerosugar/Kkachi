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
}
