import XCTest
@testable import Kkachi

/// Verifies summary counts derived from tracked tab state.
@MainActor
final class TabTrackerSummaryTests: XCTestCase {
    /// Ensures at-risk summary counts inactive tabs eligible for pruning.
    func testAtRiskSummaryCountsEligibleInactiveTabs() {
        let context = TabTrackerTestContexts.enabled { preferences in
            preferences.setThreshold(120)
        }
        context.tracker.applyPolicy(context.preferences.policy)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 70))

        XCTAssertEqual(context.tracker.summary.scannedCount, 1)
        XCTAssertEqual(context.tracker.summary.atRiskCount, 1)
    }

    /// Ensures eligible tabs outside the attention window are not called at risk.
    func testEligibleInactiveTabOutsideWindowIsNotAtRisk() {
        let context = TabTrackerTestContexts.enabled { preferences in
            preferences.setThreshold(600)
        }
        context.tracker.applyPolicy(context.preferences.policy)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(context.tracker.summary.scannedCount, 1)
        XCTAssertEqual(context.tracker.summary.atRiskCount, 0)
        XCTAssertEqual(context.tracker.trackedTabs.first?.isAtRisk, false)
    }

    /// Ensures active and excluded tabs are never treated as at risk.
    func testActiveAndExcludedTabsAreNeverAtRisk() {
        let context = TabTrackerTestContexts.enabled(tabs: [.sample(tabID: "2", isActive: true), .sample(tabID: "3", isActive: false)]) { preferences in
            preferences.addExclusion("example.com")
        }
        context.tracker.applyPolicy(context.preferences.policy)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.tracker.summary.atRiskCount, 0)
        XCTAssertTrue(context.tracker.trackedTabs.allSatisfy { !$0.isAtRisk })
    }
}
