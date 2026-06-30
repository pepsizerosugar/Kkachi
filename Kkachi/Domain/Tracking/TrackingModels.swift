import Foundation

/// Stores user choices that directly affect pruning behavior.
struct PrunePolicy: Equatable {
    /// Controls how long a background tab can remain inactive before pruning.
    var inactivityThreshold: TimeInterval

    /// Lets users pause all pruning without losing live tracking context.
    var isPaused: Bool

    /// Posts a quiet "Closed N tabs" notification after each close cycle so an automatic prune is never
    /// invisible. On by default to keep the close/restore trust loop honest; users can silence it.
    var notifyOnPrune: Bool

    /// Holds host suffix rules that protect matching tabs from automatic pruning.
    var exclusions: [DomainExclusionRule]

    /// Stores browser IDs that are allowed to participate in automatic pruning.
    var enabledBrowserIDs: Set<BrowserID>

    /// Controls how often Kkachi inspects browser state.
    var pollingInterval: TimeInterval = 60

    /// Prevents user-configured polling from creating a hot loop.
    static let minimumPollingInterval: TimeInterval = 60

    /// Caps polling at a value that still makes automatic pruning feel alive.
    static let maximumPollingInterval: TimeInterval = 60 * 60

    /// Provides conservative defaults for first launch and tests.
    static let `default` = PrunePolicy(
        inactivityThreshold: ThresholdPreset.thirtyMinutes.duration,
        isPaused: false,
        notifyOnPrune: true,
        exclusions: [],
        enabledBrowserIDs: SupportedBrowsers.ids
    )

    /// Returns true when the user policy allows the browser to be tracked.
    func isBrowserEnabled(_ browserID: BrowserID) -> Bool {
        enabledBrowserIDs.contains(browserID)
    }
}

/// Represents one simple host suffix rule such as `github.com`.
struct DomainExclusionRule: Identifiable, Equatable, Codable {
    /// Uses the normalized suffix as stable identity for SwiftUI lists.
    var id: String { hostSuffix }

    /// Stores a lowercased host suffix without leading wildcard characters.
    let hostSuffix: String

    /// Creates a normalized rule from user input, returning nil for empty input.
    init?(_ rawValue: String) {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let wildcardStripped = trimmedValue.replacingOccurrences(of: "*.", with: "")
        let normalizedValue = wildcardStripped.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        guard !normalizedValue.isEmpty else { return nil }

        self.hostSuffix = normalizedValue
    }

    /// Returns true when the URL host is exactly or suffix-matched by this rule.
    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        return host == hostSuffix || host.hasSuffix(".\(hostSuffix)")
    }
}

/// Describes a currently open tab in UI-ready form.
struct TrackedTab: Identifiable, Equatable {
    /// Reuses the browser-specific composite key for row identity.
    let id: String

    /// Identifies the browser that owns this live tab.
    let browserID: BrowserID

    /// Stores the browser-specific identity needed for manual reveal or prune commands.
    let identity: BrowserTabIdentity

    /// Points to a localized browser name for grouping and badges.
    let browserNameKey: String

    /// Keeps the browser title available for the menu row.
    let title: String

    /// Keeps the URL available for host display and restore context.
    let url: URL

    /// Records the last time the tab was active or first observed inactive.
    let lastActiveAt: Date

    /// Marks active tabs because they are never eligible for pruning.
    let isActive: Bool

    /// Marks tabs whose media playback state changes automatic close safety.
    let mediaState: BrowserMediaState

    /// Marks tabs protected by a user exclusion rule.
    let isExcluded: Bool

    /// Stores the exact date the tab will be pruned, or nil when protected.
    let pruneAt: Date?

    /// Marks whether this row is close enough to pruning to need user attention.
    let isAtRisk: Bool

    /// Marks index-based rows that should not receive destructive manual commands.
    let isIdentityAmbiguous: Bool

    /// True when this row is past its prune time but Kkachi could not auto-close it (a duplicate-identity
    /// tab it won't guess at, or a browser whose close failed). The menu shows an honest "can't auto-close"
    /// state for these instead of falsely claiming the tab is being cleaned ("정리 중").
    let isAutoCloseBlocked: Bool

    /// Provides the preferred compact host label for tab rows.
    var hostLabel: String {
        url.host ?? url.absoluteString
    }
}

/// Summarizes tracker state for the menu header.
struct TrackingSummary: Equatable {
    /// Counts all live tabs fetched during the last poll.
    let scannedCount: Int

    /// Counts tabs that are inactive, eligible, and close to pruning — and that Kkachi can actually
    /// close. Excludes auto-close-blocked rows so the "closing soon" header, mood, and menu-bar mark
    /// never promise to close a tab Kkachi has given up on.
    let atRiskCount: Int

    /// Counts overdue rows Kkachi could not auto-close (duplicate identity, or a failed close). Drives a
    /// separate honest header instead of being folded into the "closing soon" count.
    let blockedCount: Int

    /// Counts tabs protected by exclusion rules.
    let protectedCount: Int

    /// Stores the nearest upcoming prune date for header context.
    let nextPruneAt: Date?

    /// Provides an empty summary before the first successful poll.
    static let empty = TrackingSummary(scannedCount: 0, atRiskCount: 0, blockedCount: 0, protectedCount: 0, nextPruneAt: nil)
}

/// Describes setup and automation readiness for the menu permission card.
enum AutomationPermissionState: Equatable {
    /// Indicates Kkachi has not yet probed browser automation.
    case unknown

    /// Indicates the browser is not installed locally.
    case notInstalled

    /// Indicates the browser is disabled by the user's policy.
    case disabled

    /// Indicates the browser and Apple Events automation are ready.
    case ready

    /// Indicates the browser is not running, so automation cannot be probed.
    case browserMissing

    /// Indicates macOS has denied or not yet granted Apple Events permission.
    case automationDenied

}
