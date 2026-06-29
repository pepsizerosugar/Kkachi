import XCTest
@testable import Kkachi

/// Verifies the compact branch-mark menu home decisions.
@MainActor
final class KkachiMenuHomeSnapshotTests: XCTestCase {
    /// Ensures at-risk tabs make review the primary home command.
    func testAtRiskTabsUseReviewAsPrimaryAction() {
        let presentation = MenuPresentationState.make(
            status: .running,
            permission: .ready,
            summary: atRiskSummary,
            browserStatuses: [readyStatus()],
            isPaused: false
        )
        let mood = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: atRiskSummary, hasRestoreHistory: false, isPaused: false, isPruning: false)

        let snapshot = KkachiMenuHomeSnapshot.make(presentation: presentation, mood: mood, summary: atRiskSummary, hasRestoreHistory: false, isPaused: false, isPruning: false)

        XCTAssertEqual(snapshot.primaryAction, .reviewQueue)
        XCTAssertTrue(snapshot.shouldShowQueuePreview)
        XCTAssertEqual(snapshot.queuePreviewLimit, 3)
        XCTAssertFalse(snapshot.shouldShowRestorePreview)
    }

    /// Ensures recent history makes undo primary when no tab needs attention.
    func testRestoreHistoryUsesUndoAsPrimaryAction() {
        let presentation = MenuPresentationState.make(
            status: .running,
            permission: .ready,
            summary: .empty,
            browserStatuses: [readyStatus()],
            isPaused: false
        )
        let mood = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: .empty, hasRestoreHistory: true, isPaused: false, isPruning: false)

        let snapshot = KkachiMenuHomeSnapshot.make(presentation: presentation, mood: mood, summary: .empty, hasRestoreHistory: true, isPaused: false, isPruning: false)

        XCTAssertEqual(snapshot.headlineKey, "menu.home.headline.restore")
        XCTAssertEqual(snapshot.detailKey, "menu.home.detail.restore")
        XCTAssertEqual(snapshot.primaryAction, .undoLastPrune)
        XCTAssertTrue(snapshot.shouldShowRestorePreview)
        XCTAssertFalse(snapshot.shouldShowQueuePreview)
        XCTAssertEqual(snapshot.historyPreviewLimit, 3)
    }

    /// Ensures setup recovery overrides normal review and undo commands.
    func testPermissionRecoveryUsesRecoveryPrimaryAction() {
        let presentation = MenuPresentationState.make(
            status: .automationError,
            permission: .automationDenied,
            summary: atRiskSummary,
            browserStatuses: [deniedStatus()],
            isPaused: false
        )
        let mood = KkachiMoodPresentation.make(status: .automationError, permission: .automationDenied, summary: atRiskSummary, hasRestoreHistory: true, isPaused: false, isPruning: false)

        let snapshot = KkachiMenuHomeSnapshot.make(presentation: presentation, mood: mood, summary: atRiskSummary, hasRestoreHistory: true, isPaused: false, isPruning: false)

        XCTAssertEqual(snapshot.primaryAction, .retry)
        XCTAssertTrue(snapshot.shouldShowPermissionRecovery)
        XCTAssertFalse(snapshot.shouldShowQueuePreview)
        XCTAssertFalse(snapshot.shouldShowRestorePreview)
    }

    /// Ensures a healthy empty menu stays minimal and pause-focused.
    func testHealthyEmptyStateUsesPausePrimaryAction() {
        let presentation = MenuPresentationState.make(
            status: .running,
            permission: .ready,
            summary: .empty,
            browserStatuses: [readyStatus()],
            isPaused: false
        )
        let mood = KkachiMoodPresentation.make(status: .running, permission: .ready, summary: .empty, hasRestoreHistory: false, isPaused: false, isPruning: false)

        let snapshot = KkachiMenuHomeSnapshot.make(presentation: presentation, mood: mood, summary: .empty, hasRestoreHistory: false, isPaused: false, isPruning: false)

        XCTAssertEqual(snapshot.primaryAction, .pause)
        XCTAssertFalse(snapshot.shouldShowQueuePreview)
        XCTAssertFalse(snapshot.shouldShowRestorePreview)
    }

    /// Ensures user pause remains a simple resume state with no duplicate recovery card.
    func testPausedStateUsesResumeWithoutRecoveryContext() {
        let presentation = MenuPresentationState.make(
            status: .pausedByUser,
            permission: .automationDenied,
            summary: atRiskSummary,
            browserStatuses: [deniedStatus()],
            isPaused: true
        )
        let mood = KkachiMoodPresentation.make(status: .pausedByUser, permission: .automationDenied, summary: atRiskSummary, hasRestoreHistory: true, isPaused: true, isPruning: false)

        let snapshot = KkachiMenuHomeSnapshot.make(presentation: presentation, mood: mood, summary: atRiskSummary, hasRestoreHistory: true, isPaused: true, isPruning: false)

        XCTAssertEqual(snapshot.primaryAction, .resume)
        XCTAssertFalse(snapshot.shouldShowPermissionRecovery)
        XCTAssertFalse(snapshot.shouldShowQueuePreview)
        XCTAssertFalse(snapshot.shouldShowRestorePreview)
    }

    /// Provides a reusable summary with one near-prune tab.
    private var atRiskSummary: TrackingSummary {
        TrackingSummary(scannedCount: 4, atRiskCount: 1, blockedCount: 0, protectedCount: 0, nextPruneAt: Date(timeIntervalSince1970: 120))
    }

    /// Builds a status that is fully eligible for pruning.
    private func readyStatus() -> BrowserStatus {
        BrowserStatus(descriptor: .testChrome, isInstalled: true, isRunning: true, isEnabled: true, automationState: .ready, lastErrorDescription: nil)
    }

    /// Builds a browser row with denied automation permission.
    private func deniedStatus() -> BrowserStatus {
        BrowserStatus(descriptor: .testChrome, isInstalled: true, isRunning: true, isEnabled: true, automationState: .denied, lastErrorDescription: "denied")
    }
}
