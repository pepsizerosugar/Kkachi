import Foundation

/// Represents a tab after Kkachi has captured enough state to restore it.
struct PrunedTab: Identifiable, Equatable {
    /// Gives each history row a stable UI identity independent of browser IDs.
    let id: UUID

    /// Stores the page URL needed for non-destructive restore.
    let url: URL

    /// Preserves the last known title so users can recognize restored pages.
    let title: String

    /// Records when pruning happened for sorting and user context.
    let prunedAt: Date

    /// Groups every tab closed in the same poll cycle under one id so the menu can present a multi-tab
    /// close as a single "Closed N tabs" event and reopen the whole batch at once. Persisted so the
    /// grouping survives relaunch; legacy rows without one decode to their own singleton batch.
    let batchID: UUID

    /// Identifies the browser that originally owned the tab.
    let browserID: BrowserID

    /// Points to the localized browser name shown in restore history.
    let browserNameKey: String

    /// Stores the original identity for diagnostics and future restore routing.
    let originalIdentity: BrowserTabIdentity?
}

/// Serializes only the minimal restorable fields so the on-disk history stays "safely less".
/// The diagnostic `originalIdentity` is intentionally dropped and decodes back to nil — restore
/// reopens by URL in the owning browser and never depends on the original window/tab identity.
extension PrunedTab: Codable {
    /// Lists exactly the fields persisted to disk; `originalIdentity` is omitted on purpose.
    private enum CodingKeys: String, CodingKey {
        case id, url, title, prunedAt, batchID, browserID, browserNameKey
    }

    /// Rebuilds a pruned tab from disk, leaving the diagnostic identity unset. A missing `batchID`
    /// (history written before batch grouping shipped) decodes to a fresh id so each legacy row stands
    /// alone rather than collapsing unrelated tabs into one phantom batch.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            url: try container.decode(URL.self, forKey: .url),
            title: try container.decode(String.self, forKey: .title),
            prunedAt: try container.decode(Date.self, forKey: .prunedAt),
            batchID: try container.decodeIfPresent(UUID.self, forKey: .batchID) ?? UUID(),
            browserID: try container.decode(BrowserID.self, forKey: .browserID),
            browserNameKey: try container.decode(String.self, forKey: .browserNameKey),
            originalIdentity: nil
        )
    }

    /// Writes only the minimal restorable fields, never the original tab identity.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
        try container.encode(prunedAt, forKey: .prunedAt)
        try container.encode(batchID, forKey: .batchID)
        try container.encode(browserID, forKey: .browserID)
        try container.encode(browserNameKey, forKey: .browserNameKey)
    }
}

/// Describes one poll cycle's worth of closed tabs so the menu and the system notification can speak in
/// terms of a single event ("Closed 5 tabs") and offer one reopen-all action, instead of treating a
/// simultaneous multi-tab close as unrelated single closes.
struct PruneBatch: Equatable {
    /// Shares the `batchID` stamped on every `PrunedTab` closed in this cycle.
    let id: UUID

    /// Holds the tabs closed together, newest cycle first, for count and reopen-all.
    let tabs: [PrunedTab]

    /// Records when the cycle finished closing tabs, for recency-scoped status and copy.
    let closedAt: Date

    /// Counts the tabs closed in this cycle; drives the "Closed N tabs" copy and notification.
    var count: Int { tabs.count }
}

/// Represents coarse tracker states that the menu can localize safely.
enum TrackerStatus: Equatable {
    /// Indicates no supported browser is available, so polling remains paused.
    case waitingForBrowser

    /// Indicates normal polling is active.
    case running

    /// Indicates macOS sleep paused polling to avoid wasted automation calls.
    case pausedForSleep

    /// Indicates the user intentionally paused pruning from the menu or Settings.
    case pausedByUser

    /// Indicates the last AppleScript operation failed and needs user attention.
    case automationError

    /// Provides a localization key instead of hard-coded visible status text.
    var localizationKey: String {
        switch self {
        case .waitingForBrowser:
            return "tracker.status.waitingForBrowser"
        case .running:
            return "tracker.status.running"
        case .pausedForSleep:
            return "tracker.status.pausedForSleep"
        case .pausedByUser:
            return "tracker.status.pausedByUser"
        case .automationError:
            return "tracker.status.automationError"
        }
    }
}
