import AppKit
import XCTest
@testable import Kkachi

/// Verifies menu-triggered refresh behavior stays immediate and policy-safe.
@MainActor
final class TabTrackerRefreshTests: XCTestCase {
    /// Ensures opening the menu refreshes immediately instead of waiting for the next cadence tick.
    func testRefreshNowPollsImmediatelyForMenuOpen() {
        let context = TabTrackerTestContexts.enabled()
        context.tracker.start()
        XCTAssertEqual(context.adapter.fetchCount, 0, "start() defers the first poll to the timer")

        context.tracker.refreshNow()

        XCTAssertEqual(context.adapter.fetchCount, 1, "opening the menu forces one immediate poll")
        context.tracker.stop()
    }

    /// Ensures menu interaction clears a stranded display-dormancy flag and re-establishes polling.
    func testRefreshNowRecoversStrandedDisplayDormancy() {
        let context = TabTrackerTestContexts.enabled()
        context.tracker.start()
        context.tracker.handleScreensDidSleep(Notification(name: NSWorkspace.screensDidSleepNotification))
        XCTAssertTrue(context.tracker.isDormant)
        XCTAssertNil(context.tracker.timer)

        context.tracker.refreshNow()

        XCTAssertFalse(context.tracker.isDormant, "menu interaction proves the display is awake")
        XCTAssertNotNil(context.tracker.timer, "polling is re-established on menu open")
        XCTAssertEqual(context.adapter.fetchCount, 1, "a poll runs immediately after recovery")
        context.tracker.stop()
    }

    /// Ensures an explicit user pause survives opening the menu.
    func testRefreshNowRespectsUserPause() async throws {
        let context = TabTrackerTestContexts.disabled()
        context.tracker.start()
        context.store.setBrowser(context.adapter.descriptor.id, enabled: true)
        context.store.setPaused(true)
        try await TabTrackerTestContexts.waitForDeferredPolicyPoll()
        XCTAssertEqual(context.adapter.fetchCount, 0)

        context.tracker.refreshNow()

        XCTAssertEqual(context.adapter.fetchCount, 0, "a user pause survives opening the menu")
        XCTAssertEqual(context.tracker.status, .pausedByUser)
        context.tracker.stop()
    }
}
