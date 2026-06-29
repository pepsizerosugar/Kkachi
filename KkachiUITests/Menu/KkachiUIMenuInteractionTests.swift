import XCTest

/// Verifies menu interactions mutate app state and browser side effects.
final class KkachiUIMenuInteractionTests: KkachiUITestCase {
    /// Verifies the primary pause and resume commands update pruning policy.
    func testPrimaryPauseAndResumeMutatePausedState() {
        let app = launch(surface: "menu", scenario: "ready")
        let pauseButton = element("menu.primaryAction.pause", in: app)

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.paused", "false", in: app))
        XCTAssertTrue(pauseButton.waitForExistence(timeout: timeout))
        pauseButton.click()

        XCTAssertTrue(waitForState("uiTest.state.paused", "true", in: app))
        let resumeButton = element("menu.primaryAction.resume", in: app)
        XCTAssertTrue(resumeButton.waitForExistence(timeout: timeout))
        XCTAssertFalse(element("menu.context.permission", in: app).exists)
        resumeButton.click()

        XCTAssertTrue(waitForState("uiTest.state.paused", "false", in: app))
        XCTAssertTrue(element("menu.primaryAction.pause", in: app).waitForExistence(timeout: timeout))
    }

    /// Verifies review, reveal, and protect controls call their real store actions.
    func testQueueReviewRevealAndProtectActionsMutateState() {
        let app = launch(surface: "menu", scenario: "atRisk")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.atRiskCount", "1", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.revealedCount", "0", in: app))
        element("menu.primaryAction.reviewQueue", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.revealedCount", "1", in: app))

        element("menu.atRisk.reveal", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.revealedCount", "2", in: app))
        element("menu.atRisk.protect", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.exclusionCount", "1", in: app))
    }

    /// Verifies the restore affordances — the undo card and a history row — route through the browser adapter.
    func testRestoreButtonsReopenPrunedTabsThroughApp() {
        let app = launch(surface: "menu", scenario: "restore")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.historyCount", "3", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.restoredCount", "0", in: app))
        element("menu.history.undoLast", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.restoredCount", "1", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.openTabs", "1", in: app))

        element("menu.history.row", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.restoredCount", "2", in: app))
        element("menu.history.undoLast", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.restoredCount", "3", in: app))
        XCTAssertTrue(waitForState("uiTest.state.browser.openTabs", "3", in: app))
    }

    /// Verifies retry probes automation through the active browser adapter.
    func testPermissionRetryRunsAutomationProbe() {
        let app = launch(surface: "menu", scenario: "permission")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.browser.probeCount", "0", in: app))
        element("menu.primaryAction.retry", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.probeCount", "1", in: app))
    }

    /// Verifies missing-browser recovery records an app-open request without Launch Services.
    func testOpenBrowserRecoveryRecordsApplicationOpen() {
        let app = launch(surface: "menu", scenario: "browserMissing")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.browser.openApplicationCount", "0", in: app))
        element("menu.primaryAction.openBrowser", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.openApplicationCount", "1", in: app))
    }

    /// Verifies settings recovery opens a real Settings surface from the menu.
    func testOpenSettingsRecoveryShowsSettingsForm() {
        let app = launch(surface: "menu", scenario: "disabled")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        element("menu.primaryAction.openSettings", in: app).click()
        XCTAssertTrue(element("settings.form", in: app).waitForExistence(timeout: timeout))
    }

    /// Verifies footer Settings opens a real Settings surface.
    func testFooterSettingsShowsSettingsForm() {
        let app = launch(surface: "menu", scenario: "atRisk")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        element("menu.footer.settings", in: app).click()
        XCTAssertTrue(element("settings.form", in: app).waitForExistence(timeout: timeout))
    }

    /// Verifies footer pause and quit commands are wired through UI.
    func testFooterPauseAndQuitActions() {
        let app = launch(surface: "menu", scenario: "atRisk")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        element("menu.footer.pause", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.paused", "true", in: app))
        element("menu.footer.quit", in: app).click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: timeout))
    }
}
