import XCTest

/// Verifies production SwiftUI surfaces through deterministic XCUITest windows.
final class KkachiUISurfaceTests: KkachiUITestCase {
    /// Ensures the quiet menu has one pause action and no context panel.
    func testReadyMenuShowsPauseOnly() {
        let app = launch(surface: "menu", scenario: "ready")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element("menu.dashboard", in: app).exists)
        XCTAssertTrue(element("menu.primaryAction.pause", in: app).exists)
        XCTAssertFalse(element("menu.context.queue", in: app).exists)
        XCTAssertFalse(element("menu.context.restore", in: app).exists)
        XCTAssertFalse(element("menu.context.permission", in: app).exists)
    }

    /// Ensures at-risk tabs expose review as the primary action and show a queue.
    func testAtRiskMenuShowsReviewQueue() {
        let app = launch(surface: "menu", scenario: "atRisk")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element("menu.primaryAction.reviewQueue", in: app).exists)
        XCTAssertTrue(element("menu.context.queue", in: app).exists)
        XCTAssertTrue(element("menu.atRisk.row", in: app).exists)
        XCTAssertTrue(element("menu.atRisk.reveal", in: app).exists)
        XCTAssertTrue(element("menu.atRisk.protect", in: app).exists)
    }

    /// Ensures restore history exposes undo exactly once — via the richer history card — and not also as
    /// a duplicate standalone primary button stacked above it.
    func testRestoreMenuShowsUndoContext() {
        let app = launch(surface: "menu", scenario: "restore")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertFalse(element("menu.primaryAction.undoLastPrune", in: app).exists)
        XCTAssertTrue(element("menu.context.restore", in: app).exists)
        XCTAssertTrue(element("menu.history.undoLast", in: app).exists)
    }

    /// Ensures permission failures show one recovery action and one context panel.
    func testPermissionMenuShowsRecoveryContext() {
        let app = launch(surface: "menu", scenario: "permission")

        XCTAssertTrue(window("menu", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element("menu.primaryAction.retry", in: app).exists)
        XCTAssertTrue(element("menu.context.permission", in: app).exists)
        XCTAssertFalse(element("menu.context.queue", in: app).exists)
        XCTAssertFalse(element("menu.context.restore", in: app).exists)
    }

    /// Ensures settings exposes the controls promised by the menu-bar utility.
    func testSettingsSurfaceExposesCoreControls() {
        let app = launch(surface: "settings", scenario: "restore")

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element("settings.form", in: app).exists)
        XCTAssertTrue(element("settings.threshold", in: app).exists)
        XCTAssertTrue(element("settings.pause", in: app).exists)
        XCTAssertTrue(element("settings.launchAtLogin", in: app).exists)
        XCTAssertTrue(element("settings.browser.chrome", in: app).exists)
        XCTAssertTrue(element("settings.exclusions.input", in: app).exists)
        XCTAssertTrue(element("settings.exclusions.add", in: app).exists)
        XCTAssertTrue(element("settings.privacy.clearHistory", in: app).exists)
    }

}
