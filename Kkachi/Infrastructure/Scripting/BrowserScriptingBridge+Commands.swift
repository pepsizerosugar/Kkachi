import AppKit
import Foundation
import ScriptingBridge

/// Handles ScriptingBridge commands that mutate browser tabs or focus.
@MainActor
extension BrowserScriptingBridge {
    /// Closes a Chrome-compatible tab by stable window and tab IDs.
    func closeChromiumTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult {
        KkachiDebugLog.scripting("close chromium start \(KkachiDebugLog.tabContext(tab))")
        let target = try chromiumTab(identity: tab.identity, operation: "closeTab:\(descriptor.id.rawValue)")
        try performAny(["close", "delete"], on: target, operation: "closeTab:\(descriptor.id.rawValue)")
        KkachiDebugLog.scripting("close chromium finish \(KkachiDebugLog.tabContext(tab))")
        return .closed
    }

    /// Focuses a Chrome-compatible tab and brings its browser forward.
    func revealChromiumTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult {
        let operation = "revealTab:\(descriptor.id.rawValue)"
        let window = try chromiumWindow(id: tab.identity.windowID, operation: operation)
        let tabIndex = try chromiumTabIndex(identity: tab.identity, window: window, operation: operation)
        window.setValue(tabIndex, forKey: "activeTabIndex")
        window.setValue(1, forKey: "index")
        try application(operation: operation).activate()
        return .revealed
    }

    /// Reopens a pruned tab's page in its origin browser through Launch Services.
    ///
    /// Restore deliberately does NOT use the Standard Suite `open` Apple event. That command's direct
    /// parameter is typed as a file, so Cocoa Scripting coerces any URL handed to it — `NSURL` *or*
    /// `String` — into a `file://` reference, collapsing `https://host/…` into `file:///…https:/host/…`
    /// (the `//` is lost to file-path normalization). That coercion is the recurring "restored tab
    /// opens as a file" bug. Launch Services opens http(s) URLs natively and identically for Safari
    /// and every Chromium browser, so both families now share this one path and cannot drift apart
    /// again. Resolves the app by bundle id so a browser installed outside /Applications still works.
    /// Throws when the origin browser is gone, so the caller still surfaces the restore-failure
    /// fallback (its reason is derived from live browser status, not from this error).
    func restoreTab(_ tab: PrunedTab) throws {
        let operation = "restoreTab:\(descriptor.id.rawValue)"
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: descriptor.bundleIdentifier) else {
            KkachiDebugLog.scripting("restore app missing browser=\(descriptor.id.rawValue) operation=\(operation) bundle=\(descriptor.bundleIdentifier)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "applicationUnavailable")
        }
        KkachiDebugLog.scripting("restore open browser=\(descriptor.id.rawValue) operation=\(operation) url=\(tab.url.absoluteString)")
        NSWorkspace.shared.open(Self.restoreOpenItems(for: tab), withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Resolves the exact items Launch Services opens for a restore: the saved page URL, unchanged and
    /// never a file URL. Pure and nonisolated so a unit test can assert the web address survives restore.
    nonisolated static func restoreOpenItems(for tab: PrunedTab) -> [URL] {
        [tab.url]
    }

    /// Closes a Safari tab only after URL/title fingerprint validation.
    func closeSafariTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabCloseResult {
        let operation = "closeTab:\(descriptor.id.rawValue)"
        let target = try validatedSafariTab(tab, operation: operation)
        try performAny(["delete"], on: target, operation: operation)
        return .closed
    }

    /// Focuses a Safari tab after URL/title fingerprint validation.
    func revealSafariTab(_ tab: BrowserTabSnapshot) throws -> BrowserTabRevealResult {
        let operation = "revealTab:\(descriptor.id.rawValue)"
        let window = try safariWindow(index: tab.identity.windowID, operation: operation)
        let target = try validatedSafariTab(tab, operation: operation)
        window.setValue(target, forKey: "currentTab")
        window.setValue(1, forKey: "index")
        try application(operation: operation).activate()
        return .revealed
    }

    /// Finds a Chrome-compatible window by its stable scripting ID.
    private func chromiumWindow(id: String, operation: String) throws -> SBObject {
        let app = try application(operation: operation)
        let windows = try elementObjects(app.value(forKey: "windows"), operation: operation)
        guard let window = try windows.first(where: { try stringValue($0.value(forKey: "id"), operation: operation) == id }) else {
            KkachiDebugLog.scripting("chromium window missing browser=\(descriptor.id.rawValue) operation=\(operation) window=\(id) availableWindows=\(windows.count)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "windowMissing")
        }
        KkachiDebugLog.scripting("chromium window found browser=\(descriptor.id.rawValue) operation=\(operation) window=\(id)")
        return window
    }

    /// Finds a Chrome-compatible tab by its stable scripting ID.
    private func chromiumTab(identity: BrowserTabIdentity, operation: String) throws -> SBObject {
        let window = try chromiumWindow(id: identity.windowID, operation: operation)
        let tabs = try elementObjects(window.value(forKey: "tabs"), operation: operation)
        guard let tab = try tabs.first(where: { try stringValue($0.value(forKey: "id"), operation: operation) == identity.tabID }) else {
            KkachiDebugLog.scripting("chromium tab missing browser=\(descriptor.id.rawValue) operation=\(operation) window=\(identity.windowID) tab=\(identity.tabID) availableTabs=\(tabs.count)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "tabMissing")
        }
        KkachiDebugLog.scripting("chromium tab found browser=\(descriptor.id.rawValue) operation=\(operation) window=\(identity.windowID) tab=\(identity.tabID)")
        return tab
    }

    /// Finds the current one-based index for a Chrome-compatible tab ID.
    private func chromiumTabIndex(identity: BrowserTabIdentity, window: SBObject, operation: String) throws -> Int {
        let tabs = try elementObjects(window.value(forKey: "tabs"), operation: operation)
        guard let index = try tabs.firstIndex(where: { try stringValue($0.value(forKey: "id"), operation: operation) == identity.tabID }) else {
            KkachiDebugLog.scripting("chromium tab index missing browser=\(descriptor.id.rawValue) operation=\(operation) window=\(identity.windowID) tab=\(identity.tabID) availableTabs=\(tabs.count)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "tabMissing")
        }
        KkachiDebugLog.scripting("chromium tab index found browser=\(descriptor.id.rawValue) operation=\(operation) window=\(identity.windowID) tab=\(identity.tabID) index=\(index + 1)")
        return index + 1
    }

    /// Finds a Safari window by the index stored in a tab identity.
    private func safariWindow(index: String, operation: String) throws -> SBObject {
        let app = try application(operation: operation)
        let windows = try elementObjects(app.value(forKey: "windows"), operation: operation)
        guard let window = try windows.first(where: { "\(try intValue($0.value(forKey: "index"), operation: operation))" == index }) else {
            KkachiDebugLog.scripting("safari window missing browser=\(descriptor.id.rawValue) operation=\(operation) window=\(index) availableWindows=\(windows.count)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "windowMissing")
        }
        KkachiDebugLog.scripting("safari window found browser=\(descriptor.id.rawValue) operation=\(operation) window=\(index)")
        return window
    }

    /// Finds a Safari tab and verifies its URL/title fingerprint has not changed.
    private func validatedSafariTab(_ tab: BrowserTabSnapshot, operation: String) throws -> SBObject {
        let window = try safariWindow(index: tab.identity.windowID, operation: operation)
        let tabs = try elementObjects(window.value(forKey: "tabs"), operation: operation)
        guard let target = try tabs.first(where: { "\(try intValue($0.value(forKey: "index"), operation: operation))" == tab.identity.tabID }) else {
            KkachiDebugLog.scripting("safari tab missing \(KkachiDebugLog.tabContext(tab)) operation=\(operation) availableTabs=\(tabs.count)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "tabMissing")
        }
        let currentURL = try stringValue(target.value(forKey: "URL"), operation: operation)
        let currentTitle = try stringValue(target.value(forKey: "name"), operation: operation)
        let expectedURL = tab.identity.fingerprint?.urlString ?? tab.url.absoluteString
        let expectedTitle = tab.identity.fingerprint?.title ?? tab.title
        guard currentURL == expectedURL, currentTitle == expectedTitle else {
            KkachiDebugLog.scripting("safari identity changed \(KkachiDebugLog.tabContext(tab)) operation=\(operation)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "identityChanged")
        }
        KkachiDebugLog.scripting("safari tab validated \(KkachiDebugLog.tabContext(tab)) operation=\(operation)")
        return target
    }

    /// Performs the first supported no-argument ScriptingBridge command.
    private func performAny(_ selectors: [String], on object: NSObject, operation: String) throws {
        guard let selector = selectors.map(NSSelectorFromString).first(where: { object.responds(to: $0) }) else {
            KkachiDebugLog.scripting("command unsupported operation=\(operation) selectors=\(selectors.joined(separator: ",")) object=\(type(of: object))")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "unsupportedCommand")
        }
        KkachiDebugLog.scripting("command perform operation=\(operation) selector=\(NSStringFromSelector(selector)) object=\(type(of: object))")
        _ = object.perform(selector)
    }
}
