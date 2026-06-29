import AppKit
import XCTest
@testable import Kkachi

/// Verifies sleep and wake notifications gate polling without losing recovery.
@MainActor
final class TabTrackerDormancyTests: XCTestCase {
    /// Ensures display sleep stands polling down and screen wake brings the timer back.
    func testDisplaySleepPausesPollingAndWakeResumes() {
        let context = TabTrackerTestContexts.enabled()
        context.tracker.start()
        XCTAssertNotNil(context.tracker.timer)

        context.tracker.handleScreensDidSleep(Notification(name: NSWorkspace.screensDidSleepNotification))
        XCTAssertNil(context.tracker.timer, "display sleep pauses the polling timer")
        XCTAssertTrue(context.tracker.isDormant)
        XCTAssertEqual(context.tracker.status, .pausedForSleep)

        context.tracker.pollOnce()
        XCTAssertEqual(context.adapter.fetchCount, 0)
        XCTAssertEqual(context.tracker.status, .pausedForSleep)

        context.tracker.handleScreensDidWake(Notification(name: NSWorkspace.screensDidWakeNotification))
        XCTAssertNotNil(context.tracker.timer, "screen wake resumes polling")
        XCTAssertFalse(context.tracker.isDormant)
        context.tracker.stop()
    }

    /// Ensures combined system and display sleep resumes only after both wake signals arrive.
    func testCombinedDormancyResumesOnlyAfterBothWakes() {
        let context = TabTrackerTestContexts.enabled()
        context.tracker.start()

        context.tracker.handleSystemWillSleep(Notification(name: NSWorkspace.willSleepNotification))
        context.tracker.handleScreensDidSleep(Notification(name: NSWorkspace.screensDidSleepNotification))
        XCTAssertNil(context.tracker.timer)
        XCTAssertTrue(context.tracker.isDormant)

        context.tracker.handleScreensDidWake(Notification(name: NSWorkspace.screensDidWakeNotification))
        XCTAssertNil(context.tracker.timer, "first wake must not resume while the other source is dormant")
        XCTAssertTrue(context.tracker.isDormant)

        context.tracker.handleSystemDidWake(Notification(name: NSWorkspace.didWakeNotification))
        XCTAssertNotNil(context.tracker.timer, "second wake resumes polling once both sources clear")
        XCTAssertFalse(context.tracker.isDormant)
        context.tracker.stop()
    }
}
