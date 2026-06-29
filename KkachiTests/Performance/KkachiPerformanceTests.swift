import XCTest
@testable import Kkachi

/// Records repeatable Xcode performance metrics for the tracker hot paths.
@MainActor
final class KkachiPerformanceTests: XCTestCase {
    /// Tracks the fast stress sizes requested for routine performance monitoring.
    private let stressCounts = TabStressFixture.requestedCounts

    /// Ensures enabling a browser schedules polling after the Settings action returns.
    func testBrowserEnableDefersPolicyPolling() {
        let context = TabTrackerTestContexts.disabled()

        context.tracker.start()
        context.store.setBrowser(context.adapter.descriptor.id, enabled: true)

        XCTAssertEqual(context.adapter.fetchCount, 0)
        context.tracker.stop()
    }

    /// Captures wall-clock, CPU, and memory metrics for 100 mixed tabs.
    func testPolling100TabsPerformance() {
        measurePolling(tabCount: stressCounts[0])
    }

    /// Captures wall-clock, CPU, and memory metrics for 500 mixed tabs.
    func testPolling500TabsPerformance() {
        measurePolling(tabCount: stressCounts[1])
    }

    /// Captures wall-clock, CPU, and memory metrics for 1,000 mixed tabs.
    func testPolling1000TabsPerformance() {
        measurePolling(tabCount: stressCounts[2])
    }

    /// Captures the higher-risk close/history path when 1,000 inactive tabs expire.
    func testExpired1000TabPruningPerformance() {
        let measurementDate = Date(timeIntervalSince1970: 1_000)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            let context = TabStressFixture.makeTracker(tabCount: stressCounts[2])
            context.tracker.pollOnce(now: measurementDate)
            TabStressFixture.expireInactiveTabs(on: context.tracker, tabs: context.adapter.tabs, now: measurementDate)
            context.tracker.pollOnce(now: measurementDate)
            XCTAssertLessThanOrEqual(context.tracker.prunedTabs.count, TabTracker.historyLimit)
        }
    }

    /// Verifies empty, tiny, and ceiling-sized sessions keep complete summaries.
    func testPollingEdgeStressCountsKeepSummaryComplete() {
        for tabCount in [0, 1, 10, 2_000] {
            let context = TabStressFixture.makeTracker(tabCount: tabCount)
            context.tracker.pollOnce(now: Date(timeIntervalSince1970: 2_000))
            XCTAssertEqual(context.tracker.summary.scannedCount, tabCount)
        }
    }

    /// Captures the 1,000-tab path split across two supported browser adapters.
    func testMultiBrowser1000TabsPerformance() {
        let chrome = FakeBrowserAdapter(tabs: TabStressFixture.tabs(count: 500, descriptor: .testChrome), descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: TabStressFixture.tabs(count: 500, descriptor: .testWhale), descriptor: .testWhale)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())
        let measurementDate = Date(timeIntervalSince1970: 3_000)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            tracker.pollOnce(now: measurementDate)
        }

        XCTAssertEqual(tracker.summary.scannedCount, 1_000)
    }

    /// Measures one deterministic large polling pass and verifies state is complete.
    private func measurePolling(tabCount: Int) {
        let context = TabStressFixture.makeTracker(tabCount: tabCount)
        let measurementDate = Date(timeIntervalSince1970: 0)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            context.tracker.pollOnce(now: measurementDate)
        }

        XCTAssertEqual(context.tracker.summary.scannedCount, tabCount)
    }
}
