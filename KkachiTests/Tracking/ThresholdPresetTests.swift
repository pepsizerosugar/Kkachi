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

    /// Ensures polling overrides persist through the preferences store.
    @MainActor
    func testPollingIntervalPersistsInPreferences() {
        let defaults = TestDefaults.make()
        let preferences = PreferencesStore(defaults: defaults)
        preferences.setPollingInterval(120)

        let reloadedPreferences = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloadedPreferences.policy.pollingInterval, 120)
    }

    /// Ensures public polling controls cannot create too-fast or effectively dormant timers.
    @MainActor
    func testPollingIntervalClampsToPublicRange() {
        let preferences = PreferencesStore(defaults: TestDefaults.make())

        preferences.setPollingInterval(1)
        XCTAssertEqual(preferences.policy.pollingInterval, PrunePolicy.minimumPollingInterval)

        preferences.setPollingInterval(7_200)
        XCTAssertEqual(preferences.policy.pollingInterval, PrunePolicy.maximumPollingInterval)
    }
}
