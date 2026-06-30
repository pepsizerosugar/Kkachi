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

    /// Ensures audible media tabs stay open even after the normal inactivity threshold.
    func testPlayingMediaTabIsNeverPruned() {
        let mediaTab = BrowserTabSnapshot.sample(isActive: false, mediaState: .playing)
        let context = TabTrackerTestContexts.enabled(tabs: [mediaTab])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.adapter.closeCallCount, 0)
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertNil(context.tracker.trackedTabs.first?.pruneAt)
    }

    /// Ensures a tab gets a fresh inactivity window after audible media stops.
    func testPlayingMediaRefreshesInactivityClock() {
        let context = TabTrackerTestContexts.enabled(tabs: [.sample(isActive: false, mediaState: .playing)])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.adapter.tabs = [.sample(isActive: false, mediaState: .notPlaying)]
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(context.adapter.closeCallCount, 0)
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 11))
        XCTAssertEqual(context.adapter.closedTabs, ["1:2"])
    }

    /// Ensures media-probe failures fail closed instead of guessing that a tab is safe to close.
    func testUnavailableMediaStateBlocksAutomaticClose() {
        let uncertainTab = BrowserTabSnapshot.sample(isActive: false, mediaState: .unavailable)
        let context = TabTrackerTestContexts.enabled(tabs: [uncertainTab])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.adapter.closeCallCount, 0)
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertEqual(context.tracker.summary.blockedCount, 1)
        XCTAssertEqual(context.tracker.trackedTabs.first?.isAutoCloseBlocked, true)
    }

    /// Ensures a tab that starts playing after fetch but before close is not pruned.
    func testCloseTimeMediaRecheckSkipsNewPlayback() {
        let automation = FakeBrowserAdapter(tabs: [.sample(isActive: false)])
        automation.mediaStateOverride = .playing
        let context = TabTrackerTestContexts.enabled(adapter: automation)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(automation.closeCallCount, 0)
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertEqual(context.tracker.summary.blockedCount, 1)
    }
}
