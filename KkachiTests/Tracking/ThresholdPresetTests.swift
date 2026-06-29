import XCTest
@testable import Kkachi

/// Verifies build-specific threshold visibility.
final class ThresholdPresetTests: XCTestCase {
    /// Ensures debug builds retain the fast validation threshold.
    func testDebugBuildExposesTestingPreset() {
        #if DEBUG
        XCTAssertTrue(ThresholdPreset.availablePresets.contains(.testing))
        #else
        XCTAssertFalse(ThresholdPreset.availablePresets.contains(.testing))
        #endif
    }

    /// Ensures debug polling overrides persist only through the preferences store.
    @MainActor
    func testDebugPollingIntervalPersistsInPreferences() {
        #if DEBUG
        let defaults = TestDefaults.make()
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setPollingInterval(2)

        let reloadedPreferences = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloadedPreferences.policy.pollingInterval, 2)
        #endif
    }
}
