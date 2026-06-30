import Foundation

/// Automates Safari with conservative index-and-fingerprint validation.
@MainActor
final class SafariBrowserAdapter: BrowserAdapter {
    /// Describes Safari for registry and UI state.
    let descriptor: BrowserDescriptor

    /// Runs dynamic browser automation without compiling AppleScript.
    private let scriptingBridge: BrowserScriptingBridge

    /// Runs direct AppleScript for Safari's media-state JavaScript command.
    private let appleScriptBridge: AppleScriptBridge

    /// Creates an adapter for Safari.
    init(descriptor: BrowserDescriptor, scriptBridge: AppleScriptBridge) {
        self.descriptor = descriptor
        self.appleScriptBridge = scriptBridge
        self.scriptingBridge = BrowserScriptingBridge(descriptor: descriptor)
    }

    /// Reports whether Safari exists locally.
    func isInstalled() -> Bool {
        BrowserAdapterSupport.isInstalled(descriptor)
    }

    /// Reports whether Safari is currently running.
    func isRunning() -> Bool {
        BrowserAdapterSupport.isRunning(descriptor)
    }

    /// Probes Apple Events without requiring a currently open page.
    func probeAutomation() throws {
        try BrowserAdapterSupport.probeAutomation(descriptor: descriptor, scriptingBridge: scriptingBridge)
    }

    /// Fetches all Safari tabs with index-based identity and fingerprints.
    func fetchTabs() throws -> [BrowserTabSnapshot] {
        KkachiDebugLog.browser("adapter fetch start browser=\(descriptor.id.rawValue)")
        let parsedTabs = try scriptingBridge.fetchSafariTabs()
        let markedTabs = markAmbiguousIdentities(parsedTabs)
        KkachiDebugLog.browser("adapter fetch finish browser=\(descriptor.id.rawValue) tabCount=\(markedTabs.count)")
        return tabsWithMediaState(markedTabs)
    }

    /// Reads media state through AppleScript and fails closed when JavaScript access is unavailable.
    func mediaState(for tab: BrowserTabSnapshot) throws -> BrowserMediaState {
        do {
            return try appleScriptBridge.safariMediaState(tab: tab, descriptor: descriptor)
        } catch {
            if Self.isMissingTarget(error) { throw error }
            KkachiDebugLog.browser("adapter media unavailable \(KkachiDebugLog.tabContext(tab)) error=\(String(describing: error))")
            return .unavailable
        }
    }

    /// Closes a Safari tab only if its last-seen URL and title still match.
    func closeTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult {
        guard !tab.isIdentityAmbiguous else {
            KkachiDebugLog.browser("adapter close skipped reason=ambiguousIdentity \(KkachiDebugLog.tabContext(tab))")
            return .skipped(reason: .ambiguousIdentity)
        }

        do {
            KkachiDebugLog.browser("adapter close start \(KkachiDebugLog.tabContext(tab))")
            let result = try scriptingBridge.closeSafariTab(tab)
            KkachiDebugLog.browser("adapter close finish result=\(result) \(KkachiDebugLog.tabContext(tab))")
            return result
        } catch {
            if String(describing: error).contains("identityChanged") {
                KkachiDebugLog.browser("adapter close skipped reason=identityChanged \(KkachiDebugLog.tabContext(tab))")
                return .skipped(reason: .identityChanged)
            }
            throw error
        }
    }

    /// Brings a Safari tab forward only when its fingerprint still matches.
    func reveal(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult {
        guard !tab.isIdentityAmbiguous else {
            return .skipped(reason: .ambiguousIdentity)
        }

        do {
            return try scriptingBridge.revealSafariTab(tab)
        } catch {
            if String(describing: error).contains("identityChanged") {
                return .skipped(reason: .identityChanged)
            }
            throw error
        }
    }

    /// Restores the URL in Safari without requiring page scripting.
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
