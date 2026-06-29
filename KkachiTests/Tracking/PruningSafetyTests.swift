import XCTest
@testable import Kkachi

/// Verifies destructive pruning only happens after capability and identity checks.
@MainActor
final class PruningSafetyTests: XCTestCase {
    /// Ensures automation alone is enough for pruning readiness.
    func testAutomationProbeMakesBrowserEligibleWithoutPageJavaScript() {
        let context = TabTrackerTestContexts.enabled(tabs: [])

        context.tracker.refreshBrowserStatuses(probe: true)

        let status = context.tracker.browserStatuses.first
        XCTAssertEqual(status?.automationState, .ready)
        XCTAssertEqual(status?.isEligibleForPruning, true)
    }

    /// Ensures URL-only pruning writes history when automation is ready.
    func testURLOnlyPruningWritesHistoryWhenAutomationIsReady() {
        let context = TabTrackerTestContexts.enabled()

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.adapter.closedTabs, ["1:2"])
        XCTAssertEqual(context.tracker.prunedTabs.count, 1)
    }

    /// Ensures adapter safety skips keep tabs visible without raising automation errors.
    func testSkippedCloseDoesNotCreateHistoryOrAutomationError() {
        let automation = FakeBrowserAdapter(tabs: [.sample(isActive: false)])
        automation.closeResult = .skipped(reason: .identityChanged)
        let context = TabTrackerTestContexts.enabled(adapter: automation)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertEqual(automation.closeCallCount, 1)
        XCTAssertNil(context.tracker.lastErrorDescription)
    }

    /// Ensures ambiguous index-based identities are never sent to a close command.
    func testAmbiguousIdentitySkipsBeforeClose() {
        let ambiguousTab = BrowserTabSnapshot.sample(isActive: false).withIdentityAmbiguity(true)
        let context = TabTrackerTestContexts.enabled(tabs: [ambiguousTab])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.adapter.closeCallCount, 0)
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertEqual(context.tracker.trackedTabs.first?.isAtRisk, true)
    }
}
