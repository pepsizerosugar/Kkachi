import XCTest
@testable import Kkachi

/// Verifies multi-browser behavior that single-adapter tests cannot cover.
@MainActor
final class MultiBrowserTests: XCTestCase {
    /// Ensures tabs from multiple enabled browsers are evaluated together.
    func testPollMergesTabsFromMultipleBrowsers() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [.sample(tabID: "9", isActive: false, descriptor: .testWhale)], descriptor: .testWhale)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())

        tracker.pollOnce(now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(Set(tracker.trackedTabs.map(\.browserID)), [BrowserDescriptor.testChrome.id, BrowserDescriptor.testWhale.id])
        XCTAssertEqual(tracker.summary.scannedCount, 2)
    }

    /// Ensures disabled browsers are not fetched or pruned.
    func testDisabledBrowserIsIgnored() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [.sample(tabID: "9", isActive: false, descriptor: .testWhale)], descriptor: .testWhale)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        preferences.setBrowser(BrowserDescriptor.testWhale.id, enabled: false)
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())
        tracker.applyPolicy(preferences.policy)

        tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertEqual(chrome.closedTabs, ["1:2"])
        XCTAssertTrue(whale.closedTabs.isEmpty)
        XCTAssertEqual(tracker.prunedTabs.map(\.browserID), [BrowserDescriptor.testChrome.id])
    }

    /// Ensures restore requests route to the browser that created the history item.
    func testRestoreRoutesToOriginalBrowser() {
        let chrome = FakeBrowserAdapter(tabs: [], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [], descriptor: .testWhale)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())
        let history = PrunedTab.sampleHistory(url: "https://example.com/whale", descriptor: .testWhale)

        tracker.restore(history)

        XCTAssertTrue(chrome.restoredTabs.isEmpty)
        XCTAssertEqual(whale.restoredTabs.map(\.url.absoluteString), ["https://example.com/whale"])
    }

    /// Ensures permission probing tracks each supported browser row independently.
    func testPermissionProbeKeepsBrowserStatusesSeparate() {
        let chrome = FakeBrowserAdapter(tabs: [], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [], descriptor: .testWhale)
        whale.probeShouldFail = true
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())

        tracker.refreshBrowserStatuses(probe: true)

        let chromeStatus = tracker.browserStatuses.first { $0.id == BrowserDescriptor.testChrome.id }
        XCTAssertEqual(chromeStatus?.automationState, .ready)
        XCTAssertEqual(chromeStatus?.permissionState, .ready)
        XCTAssertEqual(tracker.browserStatuses.first { $0.id == BrowserDescriptor.testWhale.id }?.permissionState, .automationDenied)
    }

    /// Ensures one browser failing to automate does not collapse the whole menu into an error state.
    func testPartialBrowserFailureKeepsAppRunning() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [.sample(tabID: "9", isActive: false, descriptor: .testWhale)], descriptor: .testWhale)
        whale.fetchError = BrowserAutomationError.executionFailed(operation: "appleScriptFetchTabs:whale", details: "-600")
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())

        tracker.pollOnce(now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(tracker.status, .running, "a working browser should keep the app running")
        XCTAssertEqual(tracker.summary.scannedCount, 1)
    }

    /// Ensures a close failure degrades only that browser, without a global automation error.
    func testCloseFailureDegradesBrowserWithoutGlobalError() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        chrome.closeError = BrowserAutomationError.executionFailed(operation: "closeTab", details: "failed")
        let context = TabTrackerTestContexts.enabled(adapter: chrome)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertTrue(context.tracker.closeFailedBrowsers.contains(BrowserDescriptor.testChrome.id))
        XCTAssertEqual(context.tracker.status, .running)
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
    }

    /// Ensures a tab the user closed by hand mid-cycle (close throws tabMissing) is treated as already
    /// gone, not as a close failure: the stale row is dropped, the browser is NOT poisoned, no global
    /// error is raised, and nothing is added to restore history.
    func testHandClosedTabIsNotTreatedAsCloseFailure() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        chrome.closeError = BrowserAutomationError.executionFailed(operation: "closeTab", details: "tabMissing")
        let context = TabTrackerTestContexts.enabled(adapter: chrome)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        XCTAssertFalse(context.tracker.closeFailedBrowsers.contains(BrowserDescriptor.testChrome.id), "a tab the user already closed must not poison the browser")
        XCTAssertEqual(context.tracker.status, .running, "an already-gone tab is not an automation error")
        XCTAssertTrue(context.tracker.trackedTabs.isEmpty, "the stale row is dropped instead of lingering as 정리 중")
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty, "a tab the user closed is not added to Kkachi's restore history")
    }

    /// Ensures an overdue tab Kkachi could not close is flagged isAutoCloseBlocked, so the menu can label
    /// it honestly ("can't auto-close") instead of falsely asserting "정리 중".
    func testUnclosableOverdueTabIsFlaggedAutoCloseBlocked() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        chrome.closeError = BrowserAutomationError.executionFailed(operation: "closeTab", details: "failed")
        let context = TabTrackerTestContexts.enabled(adapter: chrome)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))

        let row = context.tracker.trackedTabs.first { $0.identity.tabID == "2" }
        XCTAssertEqual(row?.isAutoCloseBlocked, true, "an overdue tab Kkachi couldn't close is flagged for an honest label")
        XCTAssertEqual(row?.isAtRisk, true)
        XCTAssertEqual(context.tracker.summary.blockedCount, 1, "the blocked tab is counted separately")
        XCTAssertEqual(context.tracker.summary.atRiskCount, 0, "a blocked tab is never promised as closing soon")
    }

    /// Pins the gone-target classifier: hand-closed tab/window and a browser quit mid-cycle are never
    /// treated as close failures, while a genuine automation failure still is.
    func testTargetMissingClassification() {
        XCTAssertTrue(TabTracker.isTargetMissing(BrowserAutomationError.executionFailed(operation: "closeTab", details: "tabMissing")))
        XCTAssertTrue(TabTracker.isTargetMissing(BrowserAutomationError.executionFailed(operation: "closeTab", details: "windowMissing")))
        XCTAssertTrue(TabTracker.isTargetMissing(BrowserAutomationError.executionFailed(operation: "closeTab", details: "applicationNotRunning")))
        XCTAssertFalse(TabTracker.isTargetMissing(BrowserAutomationError.executionFailed(operation: "closeTab", details: "failed")))
    }

    /// Ensures Kkachi stops attempting to close a browser whose close already failed this session.
    func testCloseFailedBrowserIsSkippedOnRetry() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        chrome.closeError = BrowserAutomationError.executionFailed(operation: "closeTab", details: "failed")
        let context = TabTrackerTestContexts.enabled(adapter: chrome)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 1))
        let attemptsAfterFirstFailure = chrome.closeCallCount
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: TabTracker.inactivityThreshold + 2))

        XCTAssertEqual(chrome.closeCallCount, attemptsAfterFirstFailure, "close must not be retried after a session failure")
    }

    /// Ensures transient browser scripting failures do not permanently exclude a browser.
    func testTransientFetchFailureDoesNotDenyBrowserAutomation() {
        let whale = FakeBrowserAdapter(tabs: [.sample(tabID: "9", isActive: false, descriptor: .testWhale)], descriptor: .testWhale)
        whale.fetchError = BrowserAutomationError.executionFailed(operation: "appleScriptFetchTabs:whale", details: "NSAppleScriptErrorNumber = \"-600\";")
        let context = TabTrackerTestContexts.enabled(adapter: whale)

        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 0))
        let failedStatus = context.tracker.browserStatuses.first { $0.id == BrowserDescriptor.testWhale.id }
        whale.fetchError = nil
        context.tracker.pollOnce(now: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(failedStatus?.automationState, .unknown)
        XCTAssertEqual(whale.fetchCount, 2)
        XCTAssertEqual(context.tracker.browserStatuses.first { $0.id == BrowserDescriptor.testWhale.id }?.automationState, .ready)
        XCTAssertEqual(context.tracker.summary.scannedCount, 1)
    }

    /// Ensures a cycle that exceeds its time budget defers remaining browsers to the next tick, so a
    /// cluster of stalled browsers cannot block the main actor for tens of seconds.
    func testPollCycleBudgetDefersRemainingBrowsers() {
        let chrome = FakeBrowserAdapter(tabs: [.sample(tabID: "2", isActive: false, descriptor: .testChrome)], descriptor: .testChrome)
        let whale = FakeBrowserAdapter(tabs: [.sample(tabID: "9", isActive: false, descriptor: .testWhale)], descriptor: .testWhale)
        let preferences = PreferencesStore(defaults: TestDefaults.make())
        let tracker = TabTracker(adapters: [chrome, whale], preferences: preferences, historyStore: FakeRestoreHistoryStore(), workspaceNotifications: .testing())
        var clockCalls = 0
        let clock: () -> Date = {
            defer { clockCalls += 1 }
            return Date(timeIntervalSince1970: clockCalls >= 2 ? TabTracker.pollCycleBudget + 100 : 0)
        }

        tracker.pollOnce(now: Date(timeIntervalSince1970: 0), clock: clock)

        XCTAssertEqual(chrome.fetchCount, 1)
        XCTAssertEqual(whale.fetchCount, 0, "second browser should defer when the cycle exceeds its budget")
    }
}
