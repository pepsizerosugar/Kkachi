import AppKit
import XCTest
@testable import Kkachi

/// Verifies policy-driven polling stays deferred, coalesced, and cancellable.
@MainActor
final class TabTrackerCadenceTests: XCTestCase {
    /// Ensures rapid browser toggles produce one deferred poll instead of many.
    func testRapidPolicyChangesCoalesceIntoOneDeferredPoll() async throws {
        let context = TabTrackerTestContexts.disabled()
        context.tracker.start()

        context.store.setBrowser(context.adapter.descriptor.id, enabled: true)
        context.store.setBrowser(context.adapter.descriptor.id, enabled: false)
        context.store.setBrowser(context.adapter.descriptor.id, enabled: true)

        XCTAssertEqual(context.adapter.fetchCount, 0)
        try await TabTrackerTestContexts.waitForDeferredPolicyPoll()
        XCTAssertEqual(context.adapter.fetchCount, 1)
        context.tracker.stop()
    }

    /// Ensures stopping the tracker cancels a queued policy poll.
    func testStopCancelsPendingPolicyPoll() async throws {
        let context = TabTrackerTestContexts.disabled()
        context.tracker.start()

        context.store.setBrowser(context.adapter.descriptor.id, enabled: true)
        context.tracker.stop()

        try await TabTrackerTestContexts.waitForDeferredPolicyPoll()
        XCTAssertEqual(context.adapter.fetchCount, 0)
    }

    /// Ensures pausing from Settings cancels a queued policy poll.
    func testPauseCancelsPendingPolicyPoll() async throws {
        let context = TabTrackerTestContexts.disabled()
        context.tracker.start()

        context.store.setBrowser(context.adapter.descriptor.id, enabled: true)
        context.store.setPaused(true)

        try await TabTrackerTestContexts.waitForDeferredPolicyPoll()
        XCTAssertEqual(context.adapter.fetchCount, 0)
        XCTAssertEqual(context.tracker.status, .pausedByUser)
        context.tracker.stop()
    }

    /// Ensures polling interval changes recreate the active timer.
    func testPollingIntervalChangeRestartsActiveTimer() throws {
        let context = TabTrackerTestContexts.enabled()
        context.tracker.start()
        let initialTimer = try XCTUnwrap(context.tracker.timer)

        context.preferences.setPollingInterval(120)
        context.tracker.applyPolicy(context.preferences.policy)

        let restartedTimer = try XCTUnwrap(context.tracker.timer)
        XCTAssertFalse(initialTimer === restartedTimer)
        context.tracker.stop()
    }

    /// Ensures timer tolerance meets the energy-efficiency requirement.
    func testTimerToleranceIsAtLeastTenPercent() {
        XCTAssertGreaterThanOrEqual(TabTracker.timerTolerance, TabTracker.pollingInterval * 0.1)
        XCTAssertGreaterThanOrEqual(TabTracker.timerTolerance(for: 2), 0.2)
    }

    /// Ensures the Release polling cadence widens under power pressure.
    func testPowerAdjustedIntervalWidensUnderPowerPressure() {
        let base: TimeInterval = 60
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: false, thermalState: .nominal), 60)
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: false, thermalState: .fair), 60)
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: true, thermalState: .nominal), 180)
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: false, thermalState: .serious), 120)
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: false, thermalState: .critical), 240)
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: true, thermalState: .serious), 180)
        XCTAssertEqual(TabTracker.powerAdjustedInterval(base, lowPowerMode: true, thermalState: .critical), 240)
    }
}
