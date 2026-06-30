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

    /// Ensures the release-facing preset list includes the new full-day option.
    func testAvailablePresetsIncludeOneDay() {
        XCTAssertTrue(ThresholdPreset.availablePresets.contains(.oneDay))
        XCTAssertEqual(ThresholdPreset.oneDay.duration, 86_400)
    }

    /// Ensures custom threshold drafts choose readable units from saved durations.
    func testCustomThresholdDraftUsesReadableInitialUnit() {
        let dayDraft = CustomThresholdDraft(duration: 86_400)
        XCTAssertEqual(dayDraft.amount, 1)
        XCTAssertEqual(dayDraft.unit, .days)

        let hourDraft = CustomThresholdDraft(duration: 10_800)
        XCTAssertEqual(hourDraft.amount, 3)
        XCTAssertEqual(hourDraft.unit, .hours)

        let minuteDraft = CustomThresholdDraft(duration: 2_700)
        XCTAssertEqual(minuteDraft.amount, 45)
        XCTAssertEqual(minuteDraft.unit, .minutes)
    }

    /// Ensures custom threshold drafts persist through the same TimeInterval policy path as presets.
    func testCustomThresholdDraftConvertsAndClampsDurations() {
        XCTAssertEqual(CustomThresholdDraft(amount: 2, unit: .days).duration, 172_800)
        XCTAssertEqual(CustomThresholdDraft(amount: 3, unit: .hours).duration, 10_800)
        XCTAssertEqual(CustomThresholdDraft(amount: 45, unit: .minutes).duration, 2_700)
        XCTAssertEqual(CustomThresholdDraft(amount: 0, unit: .minutes).duration, 300)
        XCTAssertEqual(CustomThresholdDraft(amount: 8, unit: .days).duration, 604_800)
    }

    /// Ensures long thresholds surface the upcoming queue with enough notice to review.
    func testAtRiskWindowScalesUpToOneHour() {
        let policy = PrunePolicy(
            inactivityThreshold: ThresholdPreset.oneDay.duration,
            isPaused: false,
            notifyOnPrune: true,
            exclusions: [],
            enabledBrowserIDs: SupportedBrowsers.ids
        )

        XCTAssertEqual(PruneEvaluator.atRiskWindow(for: policy), 3_600)
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
