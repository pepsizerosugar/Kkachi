import Foundation

/// Adds minimal media-playback probes used to avoid closing audible tabs.
extension AppleScriptBridge {
    /// Checks audible media playback in a Chromium-family tab.
    func chromiumMediaState(tab: BrowserTabSnapshot, descriptor: BrowserDescriptor) throws -> BrowserMediaState {
        let operation = "appleScriptMediaState:\(descriptor.id.rawValue)"
        let result = try execute(
            Self.chromiumMediaStateScript(bundleIdentifier: descriptor.bundleIdentifier, tab: tab),
            operation: operation
        )
        return try Self.mediaState(from: result, operation: operation)
    }

    /// Checks audible media playback in a Safari tab.
    func safariMediaState(tab: BrowserTabSnapshot, descriptor: BrowserDescriptor) throws -> BrowserMediaState {
        let operation = "appleScriptMediaState:\(descriptor.id.rawValue)"
        let result = try execute(
            Self.safariMediaStateScript(bundleIdentifier: descriptor.bundleIdentifier, tab: tab),
            operation: operation
        )
        return try Self.mediaState(from: result, operation: operation)
    }

    /// Converts the string result into a domain media state.
    static func mediaState(from result: NSAppleEventDescriptor, operation: String) throws -> BrowserMediaState {
        switch result.stringValue {
        case "playing":
            return .playing
        case "notPlaying":
            return .notPlaying
        case "missingWindow":
            throw BrowserAutomationError.executionFailed(operation: operation, details: "windowMissing")
        case "missingTab":
            throw BrowserAutomationError.executionFailed(operation: operation, details: "tabMissing")
        default:
            throw BrowserAutomationError.executionFailed(operation: operation, details: "mediaStateUnavailable")
        }
    }

    /// Builds a Chromium script that returns only playback state, never page data.
    private static func chromiumMediaStateScript(bundleIdentifier: String, tab: BrowserTabSnapshot) -> String {
        """
        tell application id \(quotedAppleScriptString(bundleIdentifier))
            launch
            set targetWindowID to \(quotedAppleScriptString(tab.identity.windowID))
            set targetTabID to \(quotedAppleScriptString(tab.identity.tabID))
            repeat with browserWindow in windows
                if (id of browserWindow as text) is targetWindowID then
                    repeat with browserTab in tabs of browserWindow
                        if (id of browserTab as text) is targetTabID then
                            return execute browserTab javascript \(quotedAppleScriptString(mediaProbeJavaScript))
                        end if
                    end repeat
                    return "missingTab"
                end if
            end repeat
            return "missingWindow"
        end tell
        """
    }

    /// Builds a Safari script that returns only playback state, never page data.
    private static func safariMediaStateScript(bundleIdentifier: String, tab: BrowserTabSnapshot) -> String {
        """
        tell application id \(quotedAppleScriptString(bundleIdentifier))
            launch
            set targetWindowIndex to \(tab.identity.windowIndex ?? -1)
            set targetTabIndex to \(tab.identity.tabIndex ?? -1)
            repeat with browserWindow in windows
                if (index of browserWindow as integer) is targetWindowIndex then
                    repeat with browserTab in tabs of browserWindow
                        if (index of browserTab as integer) is targetTabIndex then
                            return do JavaScript \(quotedAppleScriptString(mediaProbeJavaScript)) in browserTab
                        end if
                    end repeat
                    return "missingTab"
                end if
            end repeat
            return "missingWindow"
        end tell
        """
    }

    /// Returns a string boolean for audible audio/video without reading DOM text or page content.
    private static var mediaProbeJavaScript: String {
        "(() => { const media = Array.from(document.querySelectorAll('audio,video')); const playing = media.some((element) => !element.paused && !element.ended && !element.muted && element.volume > 0); return playing ? 'playing' : 'notPlaying'; })();"
    }
}
