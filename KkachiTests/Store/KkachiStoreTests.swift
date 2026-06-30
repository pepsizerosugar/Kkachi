import XCTest
@testable import Kkachi

/// Verifies the UI-facing store without invoking real browser automation.
@MainActor
final class KkachiStoreTests: XCTestCase {
    /// Ensures setup probing reports a missing browser before AppleScript calls.
    func testPermissionProbeReportsBrowserMissing() {
        let context = StoreTestContexts.make()
        context.automation.running = false

        context.store.refreshPermissionState()

        XCTAssertEqual(context.store.visiblePermissionState, .browserMissing)
    }

    /// Ensures setup probing treats browser automation as the only required permission.
    func testPermissionProbeUsesAutomationOnly() {
        let context = StoreTestContexts.make()

        context.store.refreshPermissionState()

        XCTAssertEqual(context.store.visiblePermissionState, .ready)
        XCTAssertEqual(context.automation.probeCount, 1)
    }

    /// Ensures enabling Launch at Login calls the OS service and updates visible state.
    func testLaunchAtLoginEnableUsesLoginItemService() {
        let context = StoreTestContexts.make()

        context.store.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(context.loginItemService.requests, [true])
        XCTAssertTrue(context.store.isLaunchAtLoginEnabled)
        XCTAssertNil(context.store.loginItemErrorKey)
    }

    /// Ensures disabling Launch at Login calls the OS service and updates visible state.
    func testLaunchAtLoginDisableUsesLoginItemService() {
        let loginItemService = FakeLoginItemService(isEnabled: true)
        let context = StoreTestContexts.make(loginItemService: loginItemService)

        context.store.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(loginItemService.requests, [false])
        XCTAssertFalse(context.store.isLaunchAtLoginEnabled)
        XCTAssertNil(context.store.loginItemErrorKey)
    }

    /// Ensures Launch at Login failures preserve actual state and show an error.
    func testLaunchAtLoginFailureShowsError() {
        let context = StoreTestContexts.make()
        context.loginItemService.shouldFail = true

        context.store.setLaunchAtLoginEnabled(true)

        XCTAssertFalse(context.store.isLaunchAtLoginEnabled)
        XCTAssertEqual(context.store.loginItemErrorKey, "settings.launchAtLogin.error")
        XCTAssertNotNil(context.store.loginItemErrorDescription)
    }

    /// Ensures automation probe failures map to the permission card state.
    func testPermissionProbeFailureReportsAutomationDenied() {
        let context = StoreTestContexts.make()
        context.automation.probeShouldFail = true

        context.store.refreshPermissionState()

        XCTAssertEqual(context.store.visiblePermissionState, .automationDenied)
    }

    /// Ensures missing browser rows cannot be enabled through store commands.
    func testSetBrowserIgnoresEnableForUninstalledBrowser() {
        let automation = FakeBrowserAdapter(tabs: [])
        automation.installed = false
        let context = StoreTestContexts.make(automation: automation) { preferences in
            preferences.setBrowser(automation.descriptor.id, enabled: false)
        }

        context.store.setBrowser(automation.descriptor.id, enabled: true)

        XCTAssertFalse(context.preferences.policy.isBrowserEnabled(automation.descriptor.id))
    }

    /// Ensures first-run pruning uses the release-ready thirty-minute default.
    func testDefaultThresholdUsesThirtyMinutes() {
        let preferences = PreferencesStore(defaults: TestDefaults.make())

        XCTAssertEqual(preferences.policy.inactivityThreshold, ThresholdPreset.thirtyMinutes.duration)
    }

    /// Ensures first-run policy does not ship with protected site rules.
    func testDefaultExclusionsStartEmpty() {
        let preferences = PreferencesStore(defaults: TestDefaults.make())

        XCTAssertTrue(preferences.policy.exclusions.isEmpty)
    }

    /// Ensures app language follows macOS until the user chooses an override.
    func testDefaultAppLanguageFollowsSystem() {
        let preferences = PreferencesStore(defaults: TestDefaults.make())

        XCTAssertEqual(preferences.appLanguage, .system)
    }

    /// Ensures app language overrides persist through preferences reloads.
    func testAppLanguagePersistsInPreferences() {
        let defaults = TestDefaults.make()
        let preferences = PreferencesStore(defaults: defaults)

        preferences.setAppLanguage(.english)

        let reloadedPreferences = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloadedPreferences.appLanguage, .english)
    }

    /// Ensures corrupt language defaults cannot trap Settings in an unsupported locale.
    func testInvalidAppLanguageFallsBackToSystem() {
        let defaults = TestDefaults.make()
        defaults.set("xx-invalid", forKey: "preferences.appLanguage")

        let preferences = PreferencesStore(defaults: defaults)

        XCTAssertEqual(preferences.appLanguage, .system)
    }

    /// Ensures manual language lookup uses Kkachi's selected bundle rather than process locale.
    func testAppLocalizationUsesManualLanguageBundle() {
        XCTAssertEqual(AppLocalization.string("settings.pruning.section", language: .english), "Pruning")
        XCTAssertEqual(AppLocalization.string("settings.pruning.section", language: .korean), "정리")
    }

    /// Ensures format strings come from the selected manual language bundle.
    func testAppLocalizationFormatsManualLanguageBundle() {
        XCTAssertEqual(AppLocalization.format("menu.more.count", language: .english, 3), "+3 more")
        XCTAssertEqual(AppLocalization.format("menu.more.count", language: .korean, 3), "+3개 더")
    }

    /// Ensures clearing history does not reset live tracking context.
    func testClearHistoryPreservesTrackedTabs() {
        let context = StoreTestContexts.make(tabs: [.sample(isActive: false)])
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.prunedTabs = [.sampleHistory(url: "https://example.com/a")]

        context.store.clearHistory()

        XCTAssertTrue(context.store.prunedTabs.isEmpty)
        XCTAssertEqual(context.store.trackedTabs.count, 1)
    }
}
