import Foundation
@testable import Kkachi

/// Supplies deterministic browser adapter behavior for tests.
@MainActor
final class FakeBrowserAdapter: BrowserAdapter {
    /// Describes the fake browser row and restore target.
    let descriptor: BrowserDescriptor

    /// Controls whether the tracker believes the browser is installed.
    var installed = true

    /// Controls whether the tracker believes the browser is running.
    var running = true

    /// Controls whether the automation probe should throw.
    var probeShouldFail = false

    /// Counts probe calls so setup tests can verify behavior.
    var probeCount = 0

    /// Stores the live tabs returned by `fetchTabs`.
    var tabs: [BrowserTabSnapshot]

    /// Forces fetch to throw so tests can verify automation error classification.
    var fetchError: Error?

    /// Counts fetch calls so scheduling tests can verify deferred polling.
    var fetchCount = 0

    /// Controls close outcomes for safety-skip tests.
    var closeResult: BrowserTabCloseResult = .closed

    /// Records closed tab IDs so tests can assert pruning behavior.
    var closedTabs: [String] = []

    /// Records revealed tab IDs so tests can assert manual review routing.
    var revealedTabs: [String] = []

    /// Counts close attempts including safety skips.
    var closeCallCount = 0

    /// Counts reveal attempts including safety skips.
    var revealCallCount = 0

    /// Records restored tabs so tests can assert single-tab restore routing.
    var restoredTabs: [PrunedTab] = []

    /// Forces restore to throw so tests can verify history is preserved on failure.
    var restoreError: Error?

    /// Forces closeTab to throw so tests can verify per-browser close-failure handling.
    var closeError: Error?

    /// Overrides close-time media rechecks for race-condition tests.
    var mediaStateOverride: BrowserMediaState?

    /// Creates fake browser automation with an initial live tab list.
    init(tabs: [BrowserTabSnapshot], descriptor: BrowserDescriptor = .testChrome) {
        self.tabs = tabs
        self.descriptor = descriptor
    }

    /// Reports the configured fake install state.
    func isInstalled() -> Bool {
        installed
    }

    /// Reports the configured fake running state.
    func isRunning() -> Bool {
        running
    }

    /// Verifies probe flow and optionally simulates an automation denial.
    func probeAutomation() throws {
        probeCount += 1
        if probeShouldFail {
            throw BrowserAutomationError.executionFailed(operation: "probeAutomation", details: "denied")
        }
    }

    /// Returns the current fake live tab list.
    func fetchTabs() throws -> [BrowserTabSnapshot] {
        fetchCount += 1
        if let pendingFetchError = fetchError {
            throw pendingFetchError
        }
        return tabs
    }

    /// Returns the configured close-time media state for the tab.
    func mediaState(for tab: BrowserTabSnapshot) throws -> BrowserMediaState {
        mediaStateOverride ?? tab.mediaState
    }

    /// Records the closed tab while leaving fake tab mutation to each test.
    func closeTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult {
        closeCallCount += 1
        if let pendingCloseError = closeError {
            throw pendingCloseError
        }
        if closeResult == .closed {
            closedTabs.append("\(tab.identity.windowID):\(tab.identity.tabID)")
        }
        return closeResult
    }

    /// Records reveal requests while honoring ambiguous identity safety.
    func reveal(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult {
        revealCallCount += 1
        if tab.isIdentityAmbiguous {
            return .skipped(reason: .ambiguousIdentity)
        }
        revealedTabs.append("\(tab.identity.windowID):\(tab.identity.tabID)")
        return .revealed
    }

    /// Records restore requests for store-level assertions.
    func restore(_ tab: PrunedTab) throws {
        if let pendingRestoreError = restoreError {
            throw pendingRestoreError
        }
        restoredTabs.append(tab)
    }
}
