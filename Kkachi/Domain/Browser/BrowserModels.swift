import Foundation

/// Identifies a supported browser without coupling domain code to bundle IDs.
struct BrowserID: RawRepresentable, Hashable, Codable, Identifiable, ExpressibleByStringLiteral {
    /// Stores the stable identifier used in preferences and restore history.
    let rawValue: String

    /// Exposes the raw value as SwiftUI list identity.
    var id: String { rawValue }

    /// Creates an identifier from a persisted raw value.
    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a string literal in static browser tables.
    init(stringLiteral value: String) {
        self.rawValue = value
    }
}

/// Separates browser families that expose different AppleScript semantics.
enum BrowserFamily: String, Codable {
    /// Covers Chrome-compatible browsers with stable window and tab IDs.
    case chromium

    /// Covers Safari, whose tabs must be revalidated before closing.
    case safari
}

/// Describes automation features and safety requirements for a browser.
struct BrowserCapabilities: Equatable {
    /// Indicates whether tab IDs remain stable across polling cycles.
    let hasStableTabIDs: Bool

    /// Indicates whether the adapter must verify tab identity before closing.
    let verifiesIdentityBeforeClose: Bool
}

/// Describes one browser supported by Kkachi.
struct BrowserDescriptor: Identifiable, Equatable {
    /// Identifies the browser inside app state and preferences.
    let id: BrowserID

    /// Stores the Launch Services bundle identifier used for process checks.
    let bundleIdentifier: String

    /// Stores the exact AppleScript application name used in generated scripts.
    let appleScriptName: String

    /// Points to a localized display name in `Localizable.xcstrings`.
    let displayNameKey: String

    /// Stores the expected Applications path for opening or install checks.
    let applicationPath: String

    /// Selects the adapter implementation family.
    let family: BrowserFamily

    /// Publishes automation behavior for UI and safety checks.
    let capabilities: BrowserCapabilities
}

/// Captures enough context to find a tab again during pruning or restoration.
struct BrowserTabIdentity: Hashable {
    /// Identifies which browser owns the tab.
    let browserID: BrowserID

    /// Stores a stable window ID for Chromium or a window index for Safari.
    let windowID: String

    /// Stores a stable tab ID for Chromium or a tab index for Safari.
    let tabID: String

    /// Stores Safari's mutable window index when no stable ID is available.
    let windowIndex: Int?

    /// Stores Safari's mutable tab index when no stable ID is available.
    let tabIndex: Int?

    /// Stores a URL/title fingerprint used before destructive Safari actions.
    let fingerprint: BrowserTabFingerprint?

    /// Builds the tracker key that distinguishes tabs across browsers.
    var stableID: String {
        "\(browserID.rawValue):\(windowID):\(tabID)"
    }
}

/// Stores human-checkable tab values for last-second identity validation.
struct BrowserTabFingerprint: Hashable {
    /// Stores the URL string exactly as reported by the browser.
    let urlString: String

    /// Stores the title exactly as reported by the browser.
    let title: String

    /// Creates a fingerprint from typed URL and title values.
    init(url: URL, title: String) {
        self.urlString = url.absoluteString
        self.title = title
    }
}

/// Describes a live browser tab returned by an adapter.
struct BrowserTabSnapshot: Equatable {
    /// Stores the browser-specific identity for later automation calls.
    let identity: BrowserTabIdentity

    /// Stores the current URL visible to the browser scripting dictionary.
    let url: URL

    /// Stores the current title visible to the browser scripting dictionary.
    let title: String

    /// Marks whether this tab is selected in its window and must not be pruned.
    let isActive: Bool

    /// Points to a localized browser name for UI grouping.
    let browserNameKey: String

    /// Marks index-based identities that cannot be safely distinguished later.
    let isIdentityAmbiguous: Bool

    /// Builds the stable map key used by the inactivity tracker.
    var stableID: String { identity.stableID }

    /// Creates a tab snapshot while defaulting stable-ID browsers to unambiguous.
    init(
        identity: BrowserTabIdentity,
        url: URL,
        title: String,
        isActive: Bool,
        browserNameKey: String,
        isIdentityAmbiguous: Bool = false
    ) {
        self.identity = identity
        self.url = url
        self.title = title
        self.isActive = isActive
        self.browserNameKey = browserNameKey
        self.isIdentityAmbiguous = isIdentityAmbiguous
    }

    /// Creates a copy with updated ambiguity metadata from adapter parsing.
    func withIdentityAmbiguity(_ isAmbiguous: Bool) -> BrowserTabSnapshot {
        BrowserTabSnapshot(
            identity: identity,
            url: url,
            title: title,
            isActive: isActive,
            browserNameKey: browserNameKey,
            isIdentityAmbiguous: isAmbiguous
        )
    }
}
