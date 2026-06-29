import XCTest
@testable import Kkachi

/// Verifies inactive-tab pruning without launching or scripting real browsers.
@MainActor
final class TabTrackerPruningTests: XCTestCase {
    /// Ensures active tabs are repeatedly refreshed and never pruned.
    func testActiveTabIsNeverPruned() {
        let context = TabTrackerTestContexts.enabled(tabs: [.sample(isActive: true)])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 10))

        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertTrue(context.adapter.closedTabs.isEmpty)
    }

    /// Ensures an inactive tab older than the threshold is captured and closed.
    func testExpiredInactiveTabIsPruned() {
        let context = TabTrackerTestContexts.enabled()

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.tracker.prunedTabs.count, 1)
        XCTAssertEqual(context.adapter.closedTabs, ["1:2"])
    }

    /// Ensures tabs closed in one poll cycle share a batch id and reopen together as a single undo.
    func testMultiTabCloseGroupsIntoOneReopenableBatch() {
        let context = TabTrackerTestContexts.enabled(tabs: [.sample(tabID: "2", isActive: false), .sample(tabID: "3", isActive: false)])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(context.tracker.prunedTabs.count, 2)
        XCTAssertEqual(Set(context.tracker.prunedTabs.map(\.batchID)).count, 1, "tabs closed together must share one batch id")
        XCTAssertEqual(context.tracker.lastPruneBatch?.count, 2)

        let restored = context.tracker.restoreLastBatch()
        XCTAssertEqual(restored, 2)
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
    }

    /// Ensures separate poll cycles produce distinct batch ids, so unrelated closes never merge.
    func testSeparateCyclesGetDistinctBatchIDs() {
        let context = TabTrackerTestContexts.enabled(tabs: [.sample(tabID: "2", isActive: false)])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))
        let firstBatch = context.tracker.prunedTabs.first?.batchID

        context.adapter.tabs = [.sample(tabID: "9", isActive: false)]
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 2))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 2 * TabTracker.inactivityThreshold + 5))

        XCTAssertEqual(context.tracker.prunedTabs.count, 2)
        XCTAssertNotEqual(context.tracker.prunedTabs.first?.batchID, firstBatch, "a later cycle must open a new batch")
    }

    /// Ensures restore-by-id reopens only that batch, not whatever was closed most recently.
    func testRestoreBatchByIDReopensOnlyTheNamedBatch() {
        let context = TabTrackerTestContexts.enabled(tabs: [.sample(tabID: "2", isActive: false)])

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))
        let olderBatch = context.tracker.prunedTabs.first!.batchID

        context.adapter.tabs = [.sample(tabID: "9", isActive: false)]
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 2))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 2 * TabTracker.inactivityThreshold + 5))
        XCTAssertEqual(context.tracker.prunedTabs.count, 2)

        let restored = context.tracker.restoreBatch(idString: olderBatch.uuidString)
        XCTAssertEqual(restored, 1)
        XCTAssertEqual(context.tracker.prunedTabs.count, 1)
        XCTAssertNotEqual(context.tracker.prunedTabs.first?.batchID, olderBatch)
    }

    /// Ensures restore history remains bounded to the newest thirty entries.
    func testHistoryIsCappedAtThirtyTabs() {
        let context = TabTrackerTestContexts.enabled(tabs: [])

        for index in 0..<35 {
            context.adapter.tabs = [.sample(tabID: "\(index)", isActive: false)]
            context.tracker.pollOnce(now: Date(timeIntervalSince1970: TimeInterval(index * 1_000)))
            context.tracker.pollOnce(now: Date(timeIntervalSince1970: TimeInterval(index * 1_000) + TabTracker.inactivityThreshold + 1))
        }

        XCTAssertEqual(context.tracker.prunedTabs.count, TabTracker.historyLimit)
    }
}
