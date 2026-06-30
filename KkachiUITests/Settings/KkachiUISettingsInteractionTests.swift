import XCTest

/// Verifies Settings interactions mutate policy, storage, and fake integrations.
final class KkachiUISettingsInteractionTests: KkachiUITestCase {
    /// Verifies policy toggles update paused, login-item, and browser-enabled state.
    func testSettingsPolicyTogglesMutateState() {
        let app = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        element("settings.pause", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.paused", "true", in: app))
        element("settings.pause", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.paused", "false", in: app))

        element("settings.launchAtLogin", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.launchAtLogin", "true", in: app))
        element("settings.launchAtLogin", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.launchAtLogin", "false", in: app))

        element("settings.browser.chrome", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.chrome.enabled", "false", in: app))
        element("settings.browser.chrome", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.browser.chrome.enabled", "true", in: app))
    }

    /// Verifies uninstalled browser rows are hidden while policy remains off.
    func testSettingsHidesUninstalledBrowserRows() {
        let app = launch(surface: "settings", scenario: "uninstalled")
        let browserToggle = element("settings.browser.chrome", in: app)
        let emptyState = element("settings.browsers.emptyInstalled", in: app)

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(emptyState.waitForExistence(timeout: timeout))
        XCTAssertFalse(browserToggle.exists)
        XCTAssertTrue(waitForState("uiTest.state.browser.chrome.enabled", "false", in: app))
    }

    /// Verifies Settings does not expose non-actionable identity or motion rows.
    func testSettingsOmitsStaticIdentityMotionRows() {
        let app = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertFalse(element("settings.identity.statusMark", in: app).exists)
        XCTAssertFalse(element("settings.identity.motion", in: app).exists)
    }

    /// Verifies the threshold segmented picker writes the selected policy duration.
    func testSettingsThresholdPickerMutatesPolicy() {
        let app = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.threshold", "1800", in: app))
        element("settings.threshold.testing", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.threshold", "300", in: app))
        element("settings.threshold.hour", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.threshold", "3600", in: app))
    }

    /// Verifies the custom segment reveals a minute field, preserves the active threshold on entry, and
    /// writes an arbitrary (non-preset) duration the user types.
    func testSettingsCustomThresholdWritesArbitraryDuration() {
        let app = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        element("settings.threshold.hour", in: app).click()
        XCTAssertTrue(waitForState("uiTest.state.threshold", "3600", in: app))

        element("settings.threshold.custom", in: app).click()
        let valueField = element("settings.threshold.custom.value", in: app)
        XCTAssertTrue(valueField.waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.threshold", "3600", in: app))

        replaceText(in: valueField, with: "45")
        valueField.typeText("\n")
        XCTAssertTrue(waitForState("uiTest.state.threshold", "2700", in: app))
    }

    /// Verifies the public polling interval input updates and clamps policy values.
    func testSettingsPollingIntervalInputMutatesPolicy() {
        let app = launch(surface: "settings", scenario: "ready")
        let pollingInput = element("settings.polling.minutes", in: app)

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.pollingInterval", "60", in: app))
        replaceText(in: pollingInput, with: "5")
        XCTAssertTrue(waitForState("uiTest.state.pollingInterval", "300", in: app))
        replaceText(in: pollingInput, with: "0")
        XCTAssertTrue(waitForState("uiTest.state.pollingInterval", "60", in: app))
        replaceText(in: pollingInput, with: "90")
        XCTAssertTrue(waitForState("uiTest.state.pollingInterval", "3600", in: app))
    }

    /// Verifies the app language picker persists a manual language override and redraws localized copy.
    func testSettingsLanguagePickerMutatesAppLanguage() {
        let englishApp = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: englishApp).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.appLanguage", "system", in: englishApp))
        selectLanguage("en", in: englishApp)
        XCTAssertTrue(waitForState("uiTest.state.appLanguage", "en", in: englishApp))
        XCTAssertTrue(waitForState("uiTest.state.localizedPruningSection", "Pruning", in: englishApp))
        englishApp.terminate()

        let koreanApp = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: koreanApp).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.appLanguage", "system", in: koreanApp))
        selectLanguage("ko", in: koreanApp)
        XCTAssertTrue(waitForState("uiTest.state.appLanguage", "ko", in: koreanApp))
        XCTAssertTrue(waitForState("uiTest.state.localizedPruningSection", "정리", in: koreanApp))
    }

    /// Verifies developer timing controls are no longer part of Settings.
    func testSettingsOmitsDeveloperTimingControls() {
        let app = launch(surface: "settings", scenario: "ready")

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertFalse(element("settings.debug.thresholdSeconds", in: app).exists)
        XCTAssertFalse(element("settings.debug.pollingSeconds", in: app).exists)
        XCTAssertFalse(element("settings.debug.applyTiming", in: app).exists)
    }

    /// Verifies the only text input creates and removes domain exclusion rules.
    func testSettingsExclusionInputAddsAndRemovesRuleWithState() {
        let app = launch(surface: "settings", scenario: "ready")
        let hostSuffix = "docs.example.com"
        let input = element("settings.exclusions.input", in: app)
        let addButton = element("settings.exclusions.add", in: app)
        let removeButton = element("settings.exclusions.remove", in: app)

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.exclusionCount", "0", in: app))
        XCTAssertTrue(input.waitForExistence(timeout: timeout))
        input.click()
        input.typeText(hostSuffix)
        addButton.click()

        XCTAssertTrue(element("settings.exclusions.row", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.exclusionCount", "1", in: app))
        XCTAssertTrue(removeButton.exists)
        removeButton.click()
        XCTAssertTrue(waitForState("uiTest.state.exclusionCount", "0", in: app))
    }

    /// Verifies clear history mutates restore state and disables the command.
    func testSettingsClearHistoryClearsStateAndDisablesAction() {
        let app = launch(surface: "settings", scenario: "restore")
        let clearButton = element("settings.privacy.clearHistory", in: app)

        XCTAssertTrue(window("settings", in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForState("uiTest.state.historyCount", "3", in: app))
        XCTAssertTrue(clearButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(clearButton.isEnabled)
        clearButton.click()

        let confirmButton = element("settings.privacy.clearHistory.confirm", in: app)
        XCTAssertTrue(confirmButton.waitForExistence(timeout: timeout))
        confirmButton.click()

        XCTAssertTrue(waitForState("uiTest.state.historyCount", "0", in: app))
        XCTAssertTrue(waitForDisabled(clearButton))
    }

    /// Replaces existing text in a focused field with deterministic UI-test input.
    private func replaceText(in input: XCUIElement, with value: String) {
        input.click()
        input.typeKey(.rightArrow, modifierFlags: .command)
        input.typeKey(.delete, modifierFlags: .command)
        input.typeText(value)
    }

    /// Selects one language option after resolving fresh accessibility nodes.
    private func selectLanguage(_ suffix: String, in app: XCUIApplication) {
        let picker = element("settings.language", in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: timeout))
        picker.click()

        let option = element("settings.language.\(suffix)", in: app)
        XCTAssertTrue(option.waitForExistence(timeout: timeout))
        option.click()
    }
}
