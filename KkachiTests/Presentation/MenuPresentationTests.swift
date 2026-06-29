import AppKit
import XCTest
@testable import Kkachi

/// Verifies menu presentation decisions separate UI intent from automation state.
@MainActor
final class MenuPresentationTests: XCTestCase {
    /// Ensures healthy automation produces a quiet command-center state.
    func testReadyStateHidesRecoveryCard() {
        let state = MenuPresentationState.make(status: .running, permission: .ready, summary: .empty, browserStatuses: [readyStatus()], isPaused: false)

        XCTAssertEqual(state.headlineKey, "menu.overview.headline.ready")
        XCTAssertEqual(state.primaryAction, nil)
        XCTAssertFalse(state.shouldShowRecoveryCard)
    }

    /// Ensures uninstalled optional browsers do not expand details during healthy tracking.
    func testUninstalledOptionalBrowserDoesNotExpandReadyState() {
        let state = MenuPresentationState.make(status: .running, permission: .ready, summary: .empty, browserStatuses: [readyStatus(), uninstalledStatus()], isPaused: false)

        XCTAssertEqual(state.issueBrowserCount, 0)
        XCTAssertFalse(state.shouldExpandBrowserDetails)
    }

    /// Ensures user pause becomes a single resume command.
    func testPausedStateUsesResumeAction() {
        let state = MenuPresentationState.make(status: .pausedByUser, permission: .ready, summary: .empty, browserStatuses: [readyStatus()], isPaused: true)

        XCTAssertEqual(state.tone, .idle)
        XCTAssertEqual(state.primaryAction, .resume)
        XCTAssertFalse(state.shouldShowRecoveryCard)
    }

    /// Ensures permission failures use critical recovery hierarchy.
    func testAutomationDeniedStateUsesCriticalRetry() {
        let state = MenuPresentationState.make(status: .automationError, permission: .automationDenied, summary: .empty, browserStatuses: [deniedStatus()], isPaused: false)

        XCTAssertEqual(state.tone, .critical)
        XCTAssertEqual(state.primaryAction, .retry)
        XCTAssertTrue(state.shouldExpandBrowserDetails)
        XCTAssertTrue(state.shouldShowRecoveryCard)
    }

    /// Ensures overdue tabs Kkachi cannot auto-close get their own honest headline instead of the
    /// "closing soon" attention copy, so the hero never promises to close a tab it has given up on.
    func testBlockedTabsUseHonestHeadlineNotClosingSoon() {
        let summary = TrackingSummary(scannedCount: 3, atRiskCount: 0, blockedCount: 2, protectedCount: 0, nextPruneAt: nil)

        let state = MenuPresentationState.make(status: .running, permission: .ready, summary: summary, browserStatuses: [readyStatus()], isPaused: false)

        XCTAssertEqual(state.headlineKey, "menu.overview.headline.blocked")
        XCTAssertEqual(state.headlineCount, 2)
        XCTAssertEqual(state.detailKey, "menu.overview.detail.blocked")
    }

    /// Ensures blocked-only tabs do not push the menu-bar mark into the "closing soon" alert mood, since
    /// nothing is actually about to be auto-closed.
    func testMoodDoesNotAlertForBlockedOnlyTabs() {
        let summary = TrackingSummary(scannedCount: 3, atRiskCount: 0, blockedCount: 2, protectedCount: 0, nextPruneAt: nil)

        let mood = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: summary, hasRestoreHistory: false, isPaused: false, isPruning: false)

        XCTAssertEqual(mood.mood, .watching, "blocked tabs surface in the header, not as a false menu-bar countdown")
    }

    /// Ensures no-install setup uses Settings instead of a dead retry loop.
    func testNotInstalledStateUsesSettingsAction() {
        let state = MenuPresentationState.make(status: .waitingForBrowser, permission: .notInstalled, summary: .empty, browserStatuses: [uninstalledStatus()], isPaused: false)

        XCTAssertEqual(state.primaryAction, .openSettings)
    }

    /// Ensures disabled pruning uses Settings so users can re-enable browsers.
    func testDisabledStateUsesSettingsAction() {
        let state = MenuPresentationState.make(status: .waitingForBrowser, permission: .disabled, summary: .empty, browserStatuses: [disabledStatus()], isPaused: false)

        XCTAssertEqual(state.primaryAction, .openSettings)
    }

    /// Ensures at-risk tabs move the branch mark into a review state.
    func testMoodUsesAlertWhenTabsNeedReview() {
        let summary = TrackingSummary(scannedCount: 3, atRiskCount: 1, blockedCount: 0, protectedCount: 0, nextPruneAt: Date())

        let mood = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: summary, hasRestoreHistory: false, isPaused: false, isPruning: false)

        XCTAssertEqual(mood.mood, .alert)
        XCTAssertEqual(mood.accessibilityKey, "menu.mood.alert")
    }

    /// Ensures live monitoring outranks stale restore history, so the menu-bar bird is never frozen on
    /// "restore available" the instant any tab is ever pruned. Restore stays reachable in the menu; the
    /// branch mark only shows restore-available while nothing is actively being watched.
    func testMoodPrefersLiveWatchingOverRestoreHistory() {
        let active = TrackingSummary(scannedCount: 3, atRiskCount: 0, blockedCount: 0, protectedCount: 0, nextPruneAt: nil)
        let watching = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: active, hasRestoreHistory: true, isPaused: false, isPruning: false)
        XCTAssertEqual(watching.mood, .watching)

        let idle = TrackingSummary(scannedCount: 0, atRiskCount: 0, blockedCount: 0, protectedCount: 0, nextPruneAt: nil)
        let restore = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: idle, hasRestoreHistory: true, isPaused: false, isPruning: false)
        XCTAssertEqual(restore.mood, .restoreAvailable)
    }

    /// Ensures the brief post-close acknowledgement surfaces the pruning mark above other states.
    func testMoodUsesPruningDuringCloseAcknowledgement() {
        let summary = TrackingSummary(scannedCount: 3, atRiskCount: 1, blockedCount: 0, protectedCount: 0, nextPruneAt: Date())
        let mood = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: summary, hasRestoreHistory: true, isPaused: false, isPruning: true)
        XCTAssertEqual(mood.mood, .pruning)
    }

    /// Ensures macOS sleep renders as paused rather than a false "watching"/"ready" state.
    func testMoodUsesPausedWhenSleeping() {
        let mood = KkachiMoodPresentation.make(status: .pausedForSleep, permission: .ready, summary: .empty, hasRestoreHistory: false, isPaused: false, isPruning: false)
        XCTAssertEqual(mood.mood, .paused)
    }

    /// Lists every mood so per-mood static-icon invariants can be asserted exhaustively.
    private let allMoods: [KkachiMood] = [.calm, .watching, .alert, .pruning, .paused, .blocked, .restoreAvailable]

    /// Acceptance: a valid static still exists for every mood even before any mascot art ships, via the
    /// procedural fallback over the brand silhouette — the menu bar is never blank and never animates.
    func testProviderHasStillForEveryMood() {
        let provider = MascotFrameProvider { name in
            name == "MenuBarIcon" ? NSImage(size: NSSize(width: 18, height: 18)) : nil
        }

        for mood in allMoods {
            let image = provider.image(for: mood, fallbackSymbolName: "circle.fill")

            XCTAssertTrue(image.isTemplate, "\(mood) still must be a tintable template")
        }
    }

    /// When a mood's still art is delivered, the provider serves it normalized to the menu-bar canvas.
    func testProviderLoadsDeliveredMascotStill() {
        let provider = MascotFrameProvider { name in
            if name == "MenuBarIcon" { return NSImage(size: NSSize(width: 18, height: 18)) }
            return name == "KkachiMascot_watching_00" ? NSImage(size: NSSize(width: 36, height: 36)) : nil
        }

        let still = provider.image(for: .watching, fallbackSymbolName: "circle.fill")
        XCTAssertTrue(still.isTemplate)
        XCTAssertEqual(still.size, NSSize(width: 18, height: 18), "served stills are normalized to the menu-bar canvas")
    }

    /// Builds a status that is fully eligible for pruning.
    private func readyStatus() -> BrowserStatus {
        BrowserStatus(descriptor: .testChrome, isInstalled: true, isRunning: true, isEnabled: true, automationState: .ready, lastErrorDescription: nil)
    }

    /// Builds a status with denied automation permission.
    private func deniedStatus() -> BrowserStatus {
        BrowserStatus(descriptor: .testChrome, isInstalled: true, isRunning: true, isEnabled: true, automationState: .denied, lastErrorDescription: "denied")
    }

    /// Builds a status for a supported browser that is not installed locally.
    private func uninstalledStatus() -> BrowserStatus {
        BrowserStatus(descriptor: .testWhale, isInstalled: false, isRunning: false, isEnabled: true, automationState: .unknown, lastErrorDescription: nil)
    }

    /// Builds a status for a supported browser disabled by user policy.
    private func disabledStatus() -> BrowserStatus {
        BrowserStatus(descriptor: .testChrome, isInstalled: true, isRunning: true, isEnabled: false, automationState: .ready, lastErrorDescription: nil)
    }
}
