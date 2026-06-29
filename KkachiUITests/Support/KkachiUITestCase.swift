import XCTest

/// Provides shared launch and assertion helpers for Kkachi UI automation.
class KkachiUITestCase: XCTestCase {
    /// Bounds UI waits so failures point to missing surfaces instead of hanging.
    let timeout: TimeInterval = 5

    /// Stops each test at the first missing critical UI element.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app in the deterministic test harness instead of menu-bar mode.
    func launch(surface: String, scenario: String, tabCount: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KKACHI_UI_TEST_MODE"] = "1"
        app.launchEnvironment["KKACHI_UI_TEST_SURFACE"] = surface
        app.launchEnvironment["KKACHI_UI_TEST_SCENARIO"] = scenario
        if tabCount > 0 {
            app.launchEnvironment["KKACHI_UI_TEST_TAB_COUNT"] = "\(tabCount)"
        }
        app.launch()
        return app
    }

    /// Finds any accessibility element with the given stable identifier.
    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Finds the deterministic test harness window for the requested surface.
    func window(_ surface: String, in app: XCUIApplication) -> XCUIElement {
        app.windows["uiTest.window.\(surface)"]
    }

    /// Reads a state probe value using either accessibility value or label.
    func stateValue(_ identifier: String, in app: XCUIApplication) -> String {
        let stateElement = element(identifier, in: app)
        return (stateElement.value as? String) ?? stateElement.label
    }

    /// Waits until a state probe publishes the expected value.
    func waitForState(_ identifier: String, _ expectedValue: String, in app: XCUIApplication) -> Bool {
        let stateElement = element(identifier, in: app)
        let predicate = NSPredicate { [weak self] object, _ in
            guard let self, let element = object as? XCUIElement else { return false }
            return element.exists && self.stateValue(identifier, in: app) == expectedValue
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: stateElement)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits for SwiftUI to publish a disabled control state after an interaction.
    func waitForDisabled(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "enabled == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
