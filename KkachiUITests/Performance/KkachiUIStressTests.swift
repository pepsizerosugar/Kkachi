import XCTest

/// Verifies the deterministic UI harness under large tab-session pressure.
final class KkachiUIStressTests: KkachiUITestCase {
    /// Ensures the at-risk menu still renders and acts with 100 tabs.
    func testAtRiskMenuRenders100Tabs() {
        assertAtRiskMenu(tabCount: 100)
    }

    /// Ensures the at-risk menu still renders and acts with 500 tabs.
    func testAtRiskMenuRenders500Tabs() {
        assertAtRiskMenu(tabCount: 500)
    }

    /// Ensures the at-risk menu still renders and acts with 1,000 tabs.
    func testAtRiskMenuRenders1000Tabs() {
        assertAtRiskMenu(tabCount: 1_000)
    }

    /// Records Xcode's launch metric while loading the largest routine stress fixture.
    func testAtRiskMenuLaunchPerformanceWith1000Tabs() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            configureStressLaunch(app, tabCount: 1_000)
            app.launch()
            XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
            XCTAssertTrue(waitForState("uiTest.state.trackedCount", "1000", in: app))
            app.terminate()
        }
    }

    /// Launches a large at-risk fixture and verifies the compact menu contract holds.
    private func assertAtRiskMenu(tabCount: Int) {
        let app = launch(surface: "menu", scenario: "atRisk", tabCount: tabCount)
        let expectedCount = "\(tabCount)"

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.trackedCount", expectedCount, in: app))
        XCTAssertTrue(waitForState("uiTest.state.atRiskCount", expectedCount, in: app))
        XCTAssertTrue(element("menu.primaryAction.reviewQueue", in: app).exists)
        XCTAssertTrue(element("menu.context.queue", in: app).exists)
        XCTAssertTrue(element("menu.atRisk.row", in: app).exists)

        element("menu.primaryAction.reviewQueue", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.revealedCount", "1", in: app))
    }

    /// Applies the same launch environment as `launch` while keeping metric control local.
    private func configureStressLaunch(_ app: XCUIApplication, tabCount: Int) {
        app.launchEnvironment["KKACHI_UI_TEST_MODE"] = "1"
        app.launchEnvironment["KKACHI_UI_TEST_SURFACE"] = "menu"
        app.launchEnvironment["KKACHI_UI_TEST_SCENARIO"] = "atRisk"
        app.launchEnvironment["KKACHI_UI_TEST_TAB_COUNT"] = "\(tabCount)"
    }
}
