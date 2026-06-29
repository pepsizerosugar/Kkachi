import Foundation

/// Provides direct AppleScript fallbacks for Chromium browsers with incomplete ScriptingBridge collections.
extension AppleScriptBridge {
    /// Fetches Chromium tab snapshots through the browser's AppleScript dictionary.
    func fetchChromiumTabs(descriptor: BrowserDescriptor) throws -> [BrowserTabSnapshot] {
        let operation = "appleScriptFetchTabs:\(descriptor.id.rawValue)"
        KkachiDebugLog.scripting("appleScript fetch chromium start browser=\(descriptor.id.rawValue)")
        let result = try execute(Self.chromiumFetchScript(bundleIdentifier: descriptor.bundleIdentifier), operation: operation)
        let snapshots = try Self.chromiumSnapshots(from: result, descriptor: descriptor, operation: operation)
        KkachiDebugLog.scripting("appleScript fetch chromium finish browser=\(descriptor.id.rawValue) snapshotCount=\(snapshots.count)")
        return snapshots
    }

    /// Closes one Chromium tab through direct AppleScript window and tab ID matching.
    func closeChromiumTab(_ tab: BrowserTabSnapshot, descriptor: BrowserDescriptor) throws -> BrowserTabCloseResult {
        let operation = "appleScriptCloseTab:\(descriptor.id.rawValue)"
        let result = try execute(
            Self.chromiumCloseScript(bundleIdentifier: descriptor.bundleIdentifier, tab: tab),
            operation: operation
        )
        try Self.validateCommandResult(result, operation: operation)
        return .closed
    }

    /// Focuses one Chromium tab through direct AppleScript window and tab ID matching.
    func revealChromiumTab(_ tab: BrowserTabSnapshot, descriptor: BrowserDescriptor) throws -> BrowserTabRevealResult {
        let operation = "appleScriptRevealTab:\(descriptor.id.rawValue)"
        let result = try execute(
            Self.chromiumRevealScript(bundleIdentifier: descriptor.bundleIdentifier, tab: tab),
            operation: operation
        )
        try Self.validateCommandResult(result, operation: operation)
        return .revealed
    }

    /// Converts a list of AppleScript tab rows into Chromium snapshots.
    static func chromiumSnapshots(
        from result: NSAppleEventDescriptor,
        descriptor: BrowserDescriptor,
        operation: String
    ) throws -> [BrowserTabSnapshot] {
        let rowCount = result.numberOfItems
        guard rowCount > 0 else { return [] }

        var snapshots: [BrowserTabSnapshot] = []
        for rowIndex in 1...rowCount {
            guard let row = result.atIndex(rowIndex), row.numberOfItems >= 5 else {
                KkachiDebugLog.scripting("appleScript row malformed browser=\(descriptor.id.rawValue) operation=\(operation) row=\(rowIndex)")
                continue
            }
            let windowID = try descriptorString(row.atIndex(1), field: "windowID", operation: operation)
            let tabID = try descriptorString(row.atIndex(2), field: "tabID", operation: operation)
            let activeTabID = try descriptorString(row.atIndex(3), field: "activeTabID", operation: operation)
            let urlString = try descriptorString(row.atIndex(4), field: "url", operation: operation)
            let title = try descriptorString(row.atIndex(5), field: "title", operation: operation)
            guard let url = URL(string: urlString) else {
                KkachiDebugLog.scripting("appleScript snapshot skipped reason=invalidURL browser=\(descriptor.id.rawValue) window=\(windowID) tab=\(tabID)")
                continue
            }

            let identity = BrowserTabIdentity(
                browserID: descriptor.id,
                windowID: windowID,
                tabID: tabID,
                windowIndex: nil,
                tabIndex: nil,
                fingerprint: BrowserTabFingerprint(url: url, title: title)
            )
            snapshots.append(
                BrowserTabSnapshot(
                    identity: identity,
                    url: url,
                    title: title,
                    isActive: tabID == activeTabID,
                    browserNameKey: descriptor.displayNameKey
                )
            )
        }
        return snapshots
    }

    /// Builds a script that returns every Chromium tab as a nested AppleScript list.
    private static func chromiumFetchScript(bundleIdentifier: String) -> String {
        """
        tell application id \(quotedAppleScriptString(bundleIdentifier))
            launch
            set snapshotRows to {}
            repeat with browserWindow in windows
                set windowID to id of browserWindow as text
                set activeID to ""
                try
                    set activeID to id of active tab of browserWindow as text
                end try
                repeat with browserTab in tabs of browserWindow
                    set tabID to id of browserTab as text
                    set tabURL to URL of browserTab as text
                    set tabTitle to title of browserTab as text
                    set end of snapshotRows to {windowID, tabID, activeID, tabURL, tabTitle}
                end repeat
            end repeat
            return snapshotRows
        end tell
        """
    }

    /// Builds a script that closes a tab by stable Chromium window and tab IDs.
    private static func chromiumCloseScript(bundleIdentifier: String, tab: BrowserTabSnapshot) -> String {
        commandScript(bundleIdentifier: bundleIdentifier, tab: tab, command: "close browserTab")
    }

    /// Builds a script that focuses a tab by stable Chromium window and tab IDs.
    private static func chromiumRevealScript(bundleIdentifier: String, tab: BrowserTabSnapshot) -> String {
        commandScript(
            bundleIdentifier: bundleIdentifier,
            tab: tab,
            command: """
            set active tab index of browserWindow to tabPosition
                    set index of browserWindow to 1
                    activate
            """
        )
    }

    /// Builds the shared window/tab search loop used by direct Chromium commands.
    private static func commandScript(bundleIdentifier: String, tab: BrowserTabSnapshot, command: String) -> String {
        """
        tell application id \(quotedAppleScriptString(bundleIdentifier))
            launch
            set targetWindowID to \(quotedAppleScriptString(tab.identity.windowID))
            set targetTabID to \(quotedAppleScriptString(tab.identity.tabID))
            repeat with browserWindow in windows
                if (id of browserWindow as text) is targetWindowID then
                    set tabPosition to 1
                    repeat with browserTab in tabs of browserWindow
                        if (id of browserTab as text) is targetTabID then
                            \(command)
                            return "ok"
                        end if
                        set tabPosition to tabPosition + 1
                    end repeat
                    return "missingTab"
                end if
            end repeat
            return "missingWindow"
        end tell
        """
    }

    /// Reads a string field from one AppleEvent descriptor.
    private static func descriptorString(_ descriptor: NSAppleEventDescriptor?, field: String, operation: String) throws -> String {
        guard let value = descriptor?.stringValue else {
            KkachiDebugLog.scripting("appleScript descriptor missing operation=\(operation) field=\(field)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "missingDescriptor:\(field)")
        }
        return value
    }

    /// Maps command status strings into existing browser automation errors.
    private static func validateCommandResult(_ result: NSAppleEventDescriptor, operation: String) throws {
        let status = result.stringValue ?? "missingResult"
        if status == "ok" { return }
        if status == "missingWindow" {
            throw BrowserAutomationError.executionFailed(operation: operation, details: "windowMissing")
        }
        if status == "missingTab" {
            throw BrowserAutomationError.executionFailed(operation: operation, details: "tabMissing")
        }
        throw BrowserAutomationError.executionFailed(operation: operation, details: status)
    }
}
