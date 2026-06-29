import XCTest
@testable import Kkachi

/// Verifies user policy effects on pruning decisions.
@MainActor
final class TabTrackerPolicyTests: XCTestCase {
    /// Ensures user pause state prevents pruning and automation side effects.
    func testPausedPolicyPreventsPruning() {
        let context = TabTrackerTestContexts.enabled { preferences in
            preferences.setPaused(true)
        }
        context.tracker.applyPolicy(context.preferences.policy)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertTrue(context.adapter.closedTabs.isEmpty)
        XCTAssertEqual(context.tracker.status, .pausedByUser)
    }

    /// Ensures a custom threshold controls when pruning occurs.
    func testCustomThresholdControlsPruning() {
        let context = TabTrackerTestContexts.enabled { preferences in
            preferences.setThreshold(10)
        }
        context.tracker.applyPolicy(context.preferences.policy)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 11))

        XCTAssertEqual(context.adapter.closedTabs, ["1:2"])
    }

    /// Ensures excluded domains remain live and are counted as protected.
    func testDomainExclusionPreventsPruning() {
        let context = TabTrackerTestContexts.enabled { preferences in
            preferences.addExclusion("example.com")
        }
        context.tracker.applyPolicy(context.preferences.policy)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertTrue(context.adapter.closedTabs.isEmpty)
        XCTAssertEqual(context.tracker.trackedTabs.first?.isExcluded, true)
        XCTAssertEqual(context.tracker.summary.protectedCount, 1)
    }
}
