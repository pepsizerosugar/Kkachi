import Foundation
import ScriptingBridge

/// Wraps browser ScriptingBridge access so adapters do not compile AppleScript.
@MainActor
final class BrowserScriptingBridge {
    /// Caps synchronous Apple Event waits so browser stalls do not freeze the menu indefinitely.
    private static let automationTimeout = 5

    /// Describes the browser process targeted by this bridge.
    let descriptor: BrowserDescriptor

    /// Creates a dynamic bridge for one supported browser descriptor.
    init(descriptor: BrowserDescriptor) {
        self.descriptor = descriptor
    }

    /// Reads Chrome-compatible windows and tabs through ScriptingBridge.
    func fetchChromiumTabs() throws -> [BrowserTabSnapshot] {
        KkachiDebugLog.scripting("fetch chromium start browser=\(descriptor.id.rawValue)")
        let app = try application(operation: "fetchTabs:\(descriptor.id.rawValue)")
        let windows = try elementObjects(app.value(forKey: "windows"), operation: "fetchTabs:\(descriptor.id.rawValue)")
        KkachiDebugLog.scripting("fetch chromium windows browser=\(descriptor.id.rawValue) count=\(windows.count)")
        var snapshots: [BrowserTabSnapshot] = []
        for window in windows {
            let windowID = try stringValue(window.value(forKey: "id"), operation: "fetchTabs:\(descriptor.id.rawValue)")
            let activeTab = window.value(forKey: "activeTab") as? SBObject
            let activeTabID = try activeTab.map { try stringValue($0.value(forKey: "id"), operation: "fetchTabs:\(descriptor.id.rawValue)") }
            let tabs = try elementObjects(window.value(forKey: "tabs"), operation: "fetchTabs:\(descriptor.id.rawValue)")
            KkachiDebugLog.scripting("fetch chromium window browser=\(descriptor.id.rawValue) window=\(windowID) activeTab=\(activeTabID ?? "nil") tabCount=\(tabs.count)")
            snapshots.append(contentsOf: try tabs.compactMap { tab in
                try chromiumSnapshot(tab: tab, windowID: windowID, activeTabID: activeTabID)
            })
        }
        KkachiDebugLog.scripting("fetch chromium finish browser=\(descriptor.id.rawValue) snapshotCount=\(snapshots.count)")
        return snapshots
    }

    /// Reads Safari windows and tabs through ScriptingBridge.
    func fetchSafariTabs() throws -> [BrowserTabSnapshot] {
        KkachiDebugLog.scripting("fetch safari start browser=\(descriptor.id.rawValue)")
        let app = try application(operation: "fetchTabs:\(descriptor.id.rawValue)")
        let windows = try elementObjects(app.value(forKey: "windows"), operation: "fetchTabs:\(descriptor.id.rawValue)")
        KkachiDebugLog.scripting("fetch safari windows browser=\(descriptor.id.rawValue) count=\(windows.count)")
        var snapshots: [BrowserTabSnapshot] = []
        for window in windows {
            let windowIndex = try intValue(window.value(forKey: "index"), operation: "fetchTabs:\(descriptor.id.rawValue)")
            let currentTab = window.value(forKey: "currentTab") as? SBObject
            let currentTabIndex = try currentTab.map { try intValue($0.value(forKey: "index"), operation: "fetchTabs:\(descriptor.id.rawValue)") }
            let tabs = try elementObjects(window.value(forKey: "tabs"), operation: "fetchTabs:\(descriptor.id.rawValue)")
            KkachiDebugLog.scripting("fetch safari window browser=\(descriptor.id.rawValue) window=\(windowIndex) currentTab=\(currentTabIndex.map { String($0) } ?? "nil") tabCount=\(tabs.count)")
            snapshots.append(contentsOf: try tabs.compactMap { tab in
                try safariSnapshot(tab: tab, windowIndex: windowIndex, currentTabIndex: currentTabIndex)
            })
        }
        KkachiDebugLog.scripting("fetch safari finish browser=\(descriptor.id.rawValue) snapshotCount=\(snapshots.count)")
        return snapshots
    }

    /// Builds a configured SBApplication for the target browser.
    func application(operation: String) throws -> SBApplication {
        KkachiDebugLog.scripting("application request browser=\(descriptor.id.rawValue) operation=\(operation) bundle=\(descriptor.bundleIdentifier)")
        guard let app = SBApplication(bundleIdentifier: descriptor.bundleIdentifier) else {
            KkachiDebugLog.scripting("application unavailable browser=\(descriptor.id.rawValue) operation=\(operation)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "applicationUnavailable")
        }
        app.timeout = Self.automationTimeout
        guard app.isRunning else {
            KkachiDebugLog.scripting("application notRunning browser=\(descriptor.id.rawValue) operation=\(operation)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "applicationNotRunning")
        }
        KkachiDebugLog.scripting("application ready browser=\(descriptor.id.rawValue) operation=\(operation) timeout=\(Self.automationTimeout)")
        return app
    }

    /// Converts a dynamic ScriptingBridge collection into scriptable objects.
    ///
    /// Never fast-enumerate an `SBElementArray` (for-in / `map` / `compactMap`): its lazy enumerator
    /// pulls elements in batches through `-[NSArray getObjects:range:]`, and when the underlying
    /// browser collection shrinks mid-poll — a tab or window the user just closed by hand — the
    /// requested range overruns the now-shorter live array. AppKit then raises an Objective-C
    /// `NSRangeException` ("range … extends beyond bounds") that Swift cannot catch, crashing the
    /// whole app (the recurring `fetchChromiumTabs` poll crash). Reading by index pulls one element at
    /// a time and never issues the batch fetch, so a tab closing during a fetch degrades to a shorter
    /// list instead of a crash. `count` is snapshotted once so the loop bound cannot drift mid-read.
    func elementObjects(_ value: Any?, operation: String) throws -> [SBObject] {
        guard let elements = value as? SBElementArray else {
            KkachiDebugLog.scripting("element array missing browser=\(descriptor.id.rawValue) operation=\(operation)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "missingElementArray")
        }
        let count = elements.count
        var objects: [SBObject] = []
        objects.reserveCapacity(count)
        for index in 0..<count {
            if let object = elements.object(at: index) as? SBObject {
                objects.append(object)
            }
        }
        return objects
    }

    /// Converts browser IDs and textual properties into Swift strings.
    func stringValue(_ value: Any?, operation: String) throws -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        KkachiDebugLog.scripting("string missing browser=\(descriptor.id.rawValue) operation=\(operation) valueType=\(String(describing: type(of: value)))")
        throw BrowserAutomationError.executionFailed(operation: operation, details: "missingString")
    }

    /// Converts ScriptingBridge numeric properties into Swift integers.
    func intValue(_ value: Any?, operation: String) throws -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String, let parsedValue = Int(value) { return parsedValue }
        KkachiDebugLog.scripting("int missing browser=\(descriptor.id.rawValue) operation=\(operation) valueType=\(String(describing: type(of: value)))")
        throw BrowserAutomationError.executionFailed(operation: operation, details: "missingInt")
    }

    /// Builds a typed Chromium tab snapshot from one scriptable tab object.
    private func chromiumSnapshot(tab: SBObject, windowID: String, activeTabID: String?) throws -> BrowserTabSnapshot? {
        let operation = "fetchTabs:\(descriptor.id.rawValue)"
        let tabID = try stringValue(tab.value(forKey: "id"), operation: operation)
        let urlString = try stringValue(tab.value(forKey: "URL"), operation: operation)
        guard let url = URL(string: urlString) else {
            KkachiDebugLog.scripting("snapshot skipped reason=invalidURL browser=\(descriptor.id.rawValue) window=\(windowID) tab=\(tabID)")
            return nil
        }
        let title = try stringValue(tab.value(forKey: "title"), operation: operation)
        let identity = BrowserTabIdentity(browserID: descriptor.id, windowID: windowID, tabID: tabID, windowIndex: nil, tabIndex: nil, fingerprint: BrowserTabFingerprint(url: url, title: title))
        return BrowserTabSnapshot(identity: identity, url: url, title: title, isActive: tabID == activeTabID, browserNameKey: descriptor.displayNameKey)
    }

    /// Builds a typed Safari tab snapshot from one scriptable tab object.
    private func safariSnapshot(tab: SBObject, windowIndex: Int, currentTabIndex: Int?) throws -> BrowserTabSnapshot? {
        let operation = "fetchTabs:\(descriptor.id.rawValue)"
        let tabIndex = try intValue(tab.value(forKey: "index"), operation: operation)
        let urlString = try stringValue(tab.value(forKey: "URL"), operation: operation)
        guard let url = URL(string: urlString) else {
            KkachiDebugLog.scripting("snapshot skipped reason=invalidURL browser=\(descriptor.id.rawValue) window=\(windowIndex) tab=\(tabIndex)")
            return nil
        }
        let title = try stringValue(tab.value(forKey: "name"), operation: operation)
        let identity = BrowserTabIdentity(browserID: descriptor.id, windowID: "\(windowIndex)", tabID: "\(tabIndex)", windowIndex: windowIndex, tabIndex: tabIndex, fingerprint: BrowserTabFingerprint(url: url, title: title))
        return BrowserTabSnapshot(identity: identity, url: url, title: title, isActive: tabIndex == currentTabIndex, browserNameKey: descriptor.displayNameKey)
    }

}
