import XCTest
@testable import Kkachi

/// Verifies store-level command routing for menu actions that mutate live state.
@MainActor
final class KkachiStoreCommandTests: XCTestCase {
    /// Ensures the fast Undo card restores only the newest retained history item.
    func testRestoreLastPrunedTabRestoresNewestOnly() {
        let context = StoreTestContexts.make()
        let newest = PrunedTab.sampleHistory(url: "https://example.com/newest")
        let older = PrunedTab.sampleHistory(url: "https://example.com/older")
        context.tracker.prunedTabs = [newest, older]

        let didRestore = context.store.restoreLastPrunedTab()

        XCTAssertTrue(didRestore)
        XCTAssertEqual(context.automation.restoredTabs.map(\.url.absoluteString), ["https://example.com/newest"])
        XCTAssertEqual(context.tracker.prunedTabs.map(\.id), [older.id])
    }

    /// Ensures restoring a selected history row removes only that row.
    func testRestoreSelectedPrunedTabRemovesThatHistoryItemOnly() {
        let context = StoreTestContexts.make()
        let newest = PrunedTab.sampleHistory(url: "https://example.com/newest")
        let selected = PrunedTab.sampleHistory(url: "https://example.com/selected")
        let oldest = PrunedTab.sampleHistory(url: "https://example.com/oldest")
        context.tracker.prunedTabs = [newest, selected, oldest]

        let didRestore = context.store.restore(selected)

        XCTAssertTrue(didRestore)
        XCTAssertEqual(context.automation.restoredTabs.map(\.url.absoluteString), ["https://example.com/selected"])
        XCTAssertEqual(context.tracker.prunedTabs.map(\.id), [newest.id, oldest.id])
    }

    /// Ensures failed restores keep history available for another attempt.
    func testRestoreFailureKeepsHistoryItem() {
        let context = StoreTestContexts.make()
        context.automation.restoreError = BrowserAutomationError.executionFailed(operation: "restoreTab", details: "failed")
        let target = PrunedTab.sampleHistory(url: "https://example.com/target")
        context.tracker.prunedTabs = [target]

        let didRestore = context.store.restore(target)

        XCTAssertFalse(didRestore)
        XCTAssertTrue(context.automation.restoredTabs.isEmpty)
        XCTAssertEqual(context.tracker.prunedTabs.map(\.id), [target.id])
    }

    /// Ensures a failed restore records a row-level failure with a reason, not only a global error.
    func testRestoreFailureRecordsRowLevelFailure() {
        let context = StoreTestContexts.make()
        context.automation.restoreError = BrowserAutomationError.executionFailed(operation: "restoreTab", details: "failed")
        let target = PrunedTab.sampleHistory(url: "https://example.com/target")
        context.tracker.prunedTabs = [target]

        _ = context.store.restore(target)

        XCTAssertEqual(context.store.restoreFailure?.tabID, target.id)
        XCTAssertEqual(context.store.restoreFailure?.reason, .couldNotReopen)
    }

    /// Ensures the default-browser fallback reopens the URL and drops the history row.
    func testRestoreInDefaultBrowserOpensURLAndDropsRow() {
        let context = StoreTestContexts.make()
        context.automation.restoreError = BrowserAutomationError.executionFailed(operation: "restoreTab", details: "failed")
        let target = PrunedTab.sampleHistory(url: "https://example.com/target")
        context.tracker.prunedTabs = [target]
        _ = context.store.restore(target)

        context.store.restoreInDefaultBrowser(target)

        XCTAssertEqual(context.applicationOpener.openedURLs, [target.url])
        XCTAssertTrue(context.tracker.prunedTabs.isEmpty)
        XCTAssertNil(context.store.restoreFailure)
    }

    /// Ensures a fresh install never trips the Apple Events prompt until the user taps Connect.
    func testFirstRunDoesNotProbeUntilConnect() {
        let context = StoreTestContexts.make()

        context.store.start()

        XCTAssertEqual(context.automation.probeCount, 0, "first run must not request automation before Connect")
        XCTAssertEqual(context.store.menuHomeSnapshot.primaryAction, .connect)

        context.store.connect()

        XCTAssertGreaterThan(context.automation.probeCount, 0, "Connect should probe automation")
        XCTAssertTrue(context.preferences.hasCompletedFirstRun)
        XCTAssertNotEqual(context.store.menuHomeSnapshot.primaryAction, .connect)
    }

    /// Ensures the denied-state recovery deep-links to the macOS Automation privacy pane.
    func testOpenAutomationSettingsDeepLinks() {
        let context = StoreTestContexts.make()

        context.store.openAutomationSettings()

        XCTAssertEqual(context.applicationOpener.openedURLs.count, 1)
        XCTAssertTrue(context.applicationOpener.openedURLs.first?.absoluteString.contains("Privacy_Automation") ?? false)
    }

    /// Ensures adding an exclusion reports success so the UI can keep invalid or duplicate input.
    func testAddExclusionRejectsInvalidAndDuplicate() {
        let context = StoreTestContexts.make()

        XCTAssertTrue(context.store.addExclusion("github.com"))
        XCTAssertFalse(context.store.addExclusion("github.com"), "a duplicate should be rejected")
        XCTAssertFalse(context.store.addExclusion(""), "blank input should be rejected")
        XCTAssertEqual(context.store.preferences.policy.exclusions.count, 1)
    }

    /// Ensures a paste-many batch reports accurate added/skipped counts and that Remove All clears the
    /// whole list, covering the two new store helpers the Settings section relies on.
    func testBatchExclusionAddCountsAndRemoveAllClears() {
        let context = StoreTestContexts.make()

        let result = context.store.addExclusions(["github.com", "github.com", "notion.so", ""])
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(Set(context.store.preferences.policy.exclusions.map(\.hostSuffix)), ["github.com", "notion.so"])

        context.store.removeAllExclusions()
        XCTAssertTrue(context.store.preferences.policy.exclusions.isEmpty)
    }

    /// Ensures a returning user that already connected probes normally on launch.
    func testReturningUserProbesOnStart() {
        let context = StoreTestContexts.make { preferences in
            preferences.completeFirstRun()
        }

        context.store.start()

        XCTAssertGreaterThan(context.automation.probeCount, 0)
        XCTAssertNotEqual(context.store.menuHomeSnapshot.primaryAction, .connect)
    }
}
