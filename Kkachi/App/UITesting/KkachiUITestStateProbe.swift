#if DEBUG
import SwiftUI

/// Exposes deterministic app state to XCUITest without changing production UI.
struct KkachiUITestStateProbe: View {
    /// Observes user-facing store state after UI interactions.
    @ObservedObject var store: KkachiStore

    /// Observes fake browser side effects that prove automation paths ran.
    @ObservedObject var browserState: KkachiUITestBrowserState

    /// Stores the legacy status-mark animation default for migration-aware tests.
    @AppStorage(MenuBarStatusController.animationEnabledKey) private var isMascotAnimationEnabled = true

    /// Stores the legacy expressive-motion default for migration-aware tests.
    @AppStorage(MenuBarStatusController.expressiveMotionKey) private var isExpressiveMotionEnabled = false

    /// Renders tiny accessibility-only state values used by UI automation assertions.
    var body: some View {
        VStack(spacing: 0) {
            state("uiTest.state.paused", bool(store.preferences.policy.isPaused))
            state("uiTest.state.threshold", integer(store.preferences.policy.inactivityThreshold))
            state("uiTest.state.pollingInterval", integer(store.preferences.policy.pollingInterval))
            state("uiTest.state.appLanguage", store.preferences.appLanguage.rawValue)
            state("uiTest.state.localizedPruningSection", AppLocalization.string("settings.pruning.section", language: store.preferences.appLanguage))
            state("uiTest.state.launchAtLogin", bool(store.isLaunchAtLoginEnabled))
            state("uiTest.state.exclusionCount", integer(store.preferences.policy.exclusions.count))
            state("uiTest.state.historyCount", integer(store.prunedTabs.count))
            state("uiTest.state.trackedCount", integer(store.trackedTabs.count))
            state("uiTest.state.atRiskCount", integer(store.atRiskTabs.count))
            state("uiTest.state.blockedCount", integer(store.summary.blockedCount))
            state("uiTest.state.browser.chrome.enabled", bool(store.preferences.policy.isBrowserEnabled(browserState.descriptor.id)))
            state("uiTest.state.browser.openTabs", integer(browserState.openTabs.count))
            state("uiTest.state.browser.closedCount", integer(browserState.closedCount))
            state("uiTest.state.browser.restoredCount", integer(browserState.restoredCount))
            state("uiTest.state.browser.revealedCount", integer(browserState.revealedCount))
            state("uiTest.state.browser.probeCount", integer(browserState.probeCount))
            state("uiTest.state.browser.openApplicationCount", integer(browserState.openApplicationCount))
            state("uiTest.state.mascot.animate", bool(isMascotAnimationEnabled))
            state("uiTest.state.mascot.expressive", bool(isExpressiveMotionEnabled))
        }
        .frame(width: 1, height: 1)
        .opacity(0.01)
    }

    /// Creates one accessibility element whose value is stable for test polling.
    private func state(_ identifier: String, _ value: String) -> some View {
        Text(verbatim: value)
            .font(.system(size: 1))
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
            .accessibilityValue(value)
    }

    /// Converts booleans into compact, locale-independent test values.
    private func bool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    /// Converts numeric state into integer strings so UI tests avoid floating-point drift.
    private func integer<T: BinaryInteger>(_ value: T) -> String {
        String(value)
    }

    /// Converts time intervals into whole-second strings for threshold assertions.
    private func integer(_ value: TimeInterval) -> String {
        String(Int(value))
    }
}
#endif
