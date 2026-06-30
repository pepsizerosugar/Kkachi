import Foundation

/// Automates Chrome-compatible browsers that expose stable tab scripting IDs.
@MainActor
final class ChromiumBrowserAdapter: BrowserAdapter {
    /// Describes the concrete browser instance automated by this adapter.
    let descriptor: BrowserDescriptor

    /// Runs dynamic browser automation without compiling AppleScript.
    private let scriptingBridge: BrowserScriptingBridge

    /// Runs direct AppleScript fallbacks when ScriptingBridge collections are incomplete.
    private let appleScriptBridge: AppleScriptBridge

    /// Creates an adapter for one Chromium-family browser.
    init(descriptor: BrowserDescriptor, scriptBridge: AppleScriptBridge) {
        self.descriptor = descriptor
        self.scriptingBridge = BrowserScriptingBridge(descriptor: descriptor)
        self.appleScriptBridge = scriptBridge
    }

    /// Reports whether the app bundle exists locally.
    func isInstalled() -> Bool {
        BrowserAdapterSupport.isInstalled(descriptor)
    }

    /// Reports whether the browser process is currently running.
    func isRunning() -> Bool {
        BrowserAdapterSupport.isRunning(descriptor)
    }

    /// Probes Apple Events without requiring a currently open page.
    func probeAutomation() throws {
        try BrowserAdapterSupport.probeAutomation(descriptor: descriptor, scriptingBridge: scriptingBridge)
    }

    /// Fetches all tabs and falls back when ScriptingBridge reports an empty Chromium collection.
    func fetchTabs() throws -> [BrowserTabSnapshot] {
        KkachiDebugLog.browser("adapter fetch start browser=\(descriptor.id.rawValue)")
        let tabs = try scriptingBridge.fetchChromiumTabs()
        if tabs.isEmpty {
            KkachiDebugLog.browser("adapter fetch fallback reason=emptyScriptingBridgeResult browser=\(descriptor.id.rawValue)")
            let fallbackTabs = try appleScriptBridge.fetchChromiumTabs(descriptor: descriptor)
            KkachiDebugLog.browser("adapter fetch fallback finish browser=\(descriptor.id.rawValue) tabCount=\(fallbackTabs.count)")
            return tabsWithMediaState(fallbackTabs)
        }
        KkachiDebugLog.browser("adapter fetch finish browser=\(descriptor.id.rawValue) tabCount=\(tabs.count)")
        return tabsWithMediaState(tabs)
    }

    /// Reads media state through AppleScript and fails closed when JavaScript access is unavailable.
    func mediaState(for tab: BrowserTabSnapshot) throws -> BrowserMediaState {
        do {
            return try appleScriptBridge.chromiumMediaState(tab: tab, descriptor: descriptor)
        } catch {
            if Self.isMissingTarget(error) { throw error }
            KkachiDebugLog.browser("adapter media unavailable \(KkachiDebugLog.tabContext(tab)) error=\(String(describing: error))")
            return .unavailable
        }
    }

    /// Closes a Chromium tab by stable scripting IDs.
    func closeTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult {
        KkachiDebugLog.browser("adapter close start \(KkachiDebugLog.tabContext(tab))")
        let result: BrowserTabCloseResult
        do {
            result = try scriptingBridge.closeChromiumTab(tab)
        } catch {
            KkachiDebugLog.browser("adapter close fallback reason=scriptingBridgeError \(KkachiDebugLog.tabContext(tab)) error=\(String(describing: error))")
            result = try appleScriptBridge.closeChromiumTab(tab, descriptor: descriptor)
        }
        KkachiDebugLog.browser("adapter close finish result=\(result) \(KkachiDebugLog.tabContext(tab))")
        return result
    }

    /// Brings a Chromium tab and its window to the foreground by stable IDs.
    func reveal(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult {
        do {
            return try scriptingBridge.revealChromiumTab(tab)
        } catch {
            KkachiDebugLog.browser("adapter reveal fallback reason=scriptingBridgeError \(KkachiDebugLog.tabContext(tab)) error=\(String(describing: error))")
            return try appleScriptBridge.revealChromiumTab(tab, descriptor: descriptor)
        }
    }

    /// Restores the URL in the original browser without requiring page scripting.
    func restore(_ tab: PrunedTab) throws {
        try scriptingBridge.restoreTab(tab)
    }

    /// Adds playback safety metadata to tab snapshots without failing the whole fetch.
    private func tabsWithMediaState(_ tabs: [BrowserTabSnapshot]) -> [BrowserTabSnapshot] {
        tabs.map { tab in
            (try? mediaState(for: tab)).map(tab.withMediaState) ?? tab.withMediaState(.unavailable)
        }
    }

    /// Distinguishes a vanished tab/window from unavailable media probing.
    private static func isMissingTarget(_ error: Error) -> Bool {
        guard case let BrowserAutomationError.executionFailed(_, details) = error else { return false }
        return details == "tabMissing" || details == "windowMissing" || details == "applicationNotRunning"
    }
}
