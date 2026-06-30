#if DEBUG
import Foundation

/// Holds the store and fake integrations used by one XCUITest app launch.
struct KkachiUITestContext {
    /// Owns production state and commands under test.
    let store: KkachiStore

    /// Records browser automation side effects for UI-level assertions.
    let browserState: KkachiUITestBrowserState
}

/// Builds deterministic stores without touching real browsers or login items.
enum KkachiUITestFixtures {
    /// Creates a store and browser state matching the requested scenario.
    @MainActor
    static func makeContext(for scenario: KkachiUITestScenario, tabCount: Int = 0) -> KkachiUITestContext {
        let defaults = isolatedDefaults()
        let preferences = PreferencesStore(defaults: defaults)
        preferences.completeFirstRun()
        let browserState = KkachiUITestBrowserState(descriptor: browserDescriptor)
        let adapter = KkachiUITestBrowserAdapter(state: browserState)
        let tracker = TabTracker(
            adapters: [adapter],
            preferences: preferences,
            historyStore: RestoreHistoryStore(directory: isolatedHistoryDirectory()),
            workspaceNotifications: .testing()
        )
        let store = KkachiStore(
            preferences: preferences,
            tracker: tracker,
            loginItemService: KkachiUITestLoginItemService(),
            applicationOpener: KkachiUITestApplicationOpener(state: browserState),
            pasteboardWriter: KkachiUITestPasteboardWriter()
        )
        configure(tracker: tracker, store: store, browserState: browserState, scenario: scenario)
        configureStressTabs(tracker: tracker, browserState: browserState, scenario: scenario, tabCount: tabCount)
        return KkachiUITestContext(store: store, browserState: browserState)
    }

    /// Uses Chrome metadata because it exercises the normal ready browser UI.
    private static var browserDescriptor: BrowserDescriptor {
        BrowserRegistry.supportedDescriptors[0]
    }

    /// Creates a defaults container that cannot leak into user preferences.
    private static func isolatedDefaults() -> UserDefaults {
        let suiteName = "KkachiUITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Keeps UI-test restore history away from production Application Support.
    private static func isolatedHistoryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KkachiUITests-\(UUID().uuidString)", isDirectory: true)
    }

    /// Applies scenario state directly so UI tests avoid real Apple Events.
    @MainActor
    private static func configure(tracker: TabTracker, store: KkachiStore, browserState: KkachiUITestBrowserState, scenario: KkachiUITestScenario) {
        resetStatusMarkDefaults()
        configureBrowserState(browserState, scenario: scenario)
        if scenario == .disabled || scenario == .uninstalled {
            store.setBrowser(browserDescriptor.id, enabled: false)
        }
        tracker.status = scenario == .permission ? .automationError : .running
        tracker.browserStatuses = [browserStatus(for: scenario, store: store, browserState: browserState)]
        tracker.trackedTabs = scenario == .atRisk ? [trackedTab()] : []
        tracker.prunedTabs = scenario == .restore ? [prunedTab(index: 0), prunedTab(index: 1), prunedTab(index: 2)] : []
        tracker.summary = summary(for: scenario)
        store.permissionState = permissionState(for: scenario)
        if scenario == .expired || scenario == .mediaPlaying || scenario == .mediaUnavailable {
            evaluateExpiredTab(tracker: tracker, browserState: browserState)
        }
    }

    /// Resets legacy status-mark defaults so UI tests are independent.
    @MainActor
    private static func resetStatusMarkDefaults() {
        UserDefaults.standard.set(true, forKey: MenuBarStatusController.animationEnabledKey)
        UserDefaults.standard.set(false, forKey: MenuBarStatusController.expressiveMotionKey)
    }

    /// Configures browser process facts and live tabs for one scenario.
    @MainActor
    private static func configureBrowserState(_ browserState: KkachiUITestBrowserState, scenario: KkachiUITestScenario) {
        browserState.isInstalled = scenario != .uninstalled
        browserState.isRunning = scenario != .browserMissing && scenario != .uninstalled
        browserState.automationState = scenario == .permission ? .denied : .ready
        switch scenario {
        case .expired:
            browserState.openTabs = [snapshot(windowID: "1", tabID: "expired", title: "Expired Article", path: "expired", isActive: false)]
        case .mediaPlaying:
            browserState.openTabs = [snapshot(windowID: "1", tabID: "media", title: "Playing Video", path: "watch", isActive: false, mediaState: .playing)]
        case .mediaUnavailable:
            browserState.openTabs = [snapshot(windowID: "1", tabID: "media-unavailable", title: "Unknown Media", path: "unknown-media", isActive: false, mediaState: .unavailable)]
        case .ready, .atRisk, .restore, .permission, .browserMissing, .disabled, .uninstalled:
            browserState.openTabs = []
        }
    }

    /// Replaces the tiny at-risk fixture with a large UI stress dataset when requested.
    @MainActor
    private static func configureStressTabs(tracker: TabTracker, browserState: KkachiUITestBrowserState, scenario: KkachiUITestScenario, tabCount: Int) {
        guard scenario == .atRisk, tabCount > 0 else { return }

        let snapshots = KkachiUITestStressFixtures.snapshots(count: tabCount, descriptor: browserDescriptor)
        let trackedTabs = KkachiUITestStressFixtures.trackedTabs(count: tabCount, descriptor: browserDescriptor)
        browserState.openTabs = snapshots
        tracker.trackedTabs = trackedTabs
        tracker.summary = KkachiUITestStressFixtures.summary(for: trackedTabs)
    }

    /// Creates one browser readiness row for the scenario.
    @MainActor
    private static func browserStatus(for scenario: KkachiUITestScenario, store: KkachiStore, browserState: KkachiUITestBrowserState) -> BrowserStatus {
        BrowserStatus(descriptor: browserDescriptor, isInstalled: browserState.isInstalled, isRunning: browserState.isRunning, isEnabled: store.preferences.policy.isBrowserEnabled(browserDescriptor.id), automationState: browserState.automationState, lastErrorDescription: nil)
    }

    /// Creates summary data that drives the menu context section.
    private static func summary(for scenario: KkachiUITestScenario) -> TrackingSummary {
        scenario == .atRisk ? TrackingSummary(scannedCount: 2, atRiskCount: 1, blockedCount: 0, protectedCount: 0, nextPruneAt: Date().addingTimeInterval(120)) : .empty
    }

    /// Provides the compact permission state shown by menu recovery UI.
    private static func permissionState(for scenario: KkachiUITestScenario) -> AutomationPermissionState {
        switch scenario {
        case .permission:
            return .automationDenied
        case .browserMissing:
            return .browserMissing
        case .disabled:
            return .disabled
        case .uninstalled:
            return .notInstalled
        case .ready, .atRisk, .restore, .expired, .mediaPlaying, .mediaUnavailable:
            return .ready
        }
    }

    /// Runs a real tracker polling pass so media and close rules are exercised.
    @MainActor
    private static func evaluateExpiredTab(tracker: TabTracker, browserState: KkachiUITestBrowserState) {
        let now = Date()
        guard let tab = browserState.openTabs.first else { return }
        tracker.lastActiveDates[tab.stableID] = now.addingTimeInterval(-PrunePolicy.default.inactivityThreshold - 10)
        tracker.pollOnce(now: now)
    }

    /// Creates one at-risk tab that looks like real browser data.
    private static func trackedTab() -> TrackedTab {
        let tab = snapshot(windowID: "1", tabID: "2", title: "Example Article", path: "reading", isActive: false)
        return TrackedTab(id: tab.stableID, browserID: browserDescriptor.id, identity: tab.identity, browserNameKey: browserDescriptor.displayNameKey, title: tab.title, url: tab.url, lastActiveAt: Date().addingTimeInterval(-1_500), isActive: false, mediaState: .notPlaying, isExcluded: false, pruneAt: Date().addingTimeInterval(120), isAtRisk: true, isIdentityAmbiguous: false, isAutoCloseBlocked: false)
    }

    /// Creates one restore history row that looks like real browser data.
    private static func prunedTab(index: Int) -> PrunedTab {
        PrunedTab(id: UUID(), url: URL(string: "https://example.com/restored-\(index)")!, title: "Restorable Article \(index)", prunedAt: Date().addingTimeInterval(TimeInterval(-90 - index)), batchID: UUID(), browserID: browserDescriptor.id, browserNameKey: browserDescriptor.displayNameKey, originalIdentity: nil)
    }

    /// Creates one browser snapshot with stable identity metadata.
    private static func snapshot(windowID: String, tabID: String, title: String, path: String, isActive: Bool, mediaState: BrowserMediaState = .notPlaying) -> BrowserTabSnapshot {
        let url = URL(string: "https://example.com/\(path)")!
        let identity = BrowserTabIdentity(browserID: browserDescriptor.id, windowID: windowID, tabID: tabID, windowIndex: nil, tabIndex: nil, fingerprint: BrowserTabFingerprint(url: url, title: title))
        return BrowserTabSnapshot(identity: identity, url: url, title: title, isActive: isActive, mediaState: mediaState, browserNameKey: browserDescriptor.displayNameKey)
    }
}
#endif
