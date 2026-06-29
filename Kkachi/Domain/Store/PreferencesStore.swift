import Combine
import Foundation

/// Persists lightweight user preferences that shape pruning behavior.
@MainActor
final class PreferencesStore: ObservableObject {
    /// Publishes the full policy so tracker and settings updates stay atomic.
    @Published private(set) var policy: PrunePolicy

    /// Publishes whether the user has completed first-run setup (tapped Connect at least once).
    @Published private(set) var hasCompletedFirstRun: Bool

    /// Stores preferences in the provided defaults container for test isolation.
    private let defaults: UserDefaults

    /// Groups all UserDefaults keys in one place to avoid string drift.
    private enum Key {
        static let threshold = "preferences.threshold"

        static let paused = "preferences.paused"

        static let notifyOnPrune = "preferences.notifyOnPrune"

        static let exclusions = "preferences.exclusions"

        static let enabledBrowsers = "preferences.enabledBrowsers"

        static let firstRunCompleted = "preferences.firstRunCompleted"

        #if DEBUG
        static let pollingInterval = "preferences.debug.pollingInterval"
        #endif
    }

    /// Loads policy from persistent defaults or uses safe first-run defaults.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedThreshold = defaults.object(forKey: Key.threshold) as? Double
        let savedExclusions = defaults.stringArray(forKey: Key.exclusions) ?? []
        let exclusionRules = savedExclusions.compactMap(DomainExclusionRule.init)
        let savedBrowsers = defaults.stringArray(forKey: Key.enabledBrowsers)
        let enabledBrowsers = Set((savedBrowsers ?? SupportedBrowsers.ids.map(\.rawValue)).map(BrowserID.init(rawValue:)))

        let notifyOnPrune = defaults.object(forKey: Key.notifyOnPrune) as? Bool ?? PrunePolicy.default.notifyOnPrune

        var loadedPolicy = PrunePolicy(
            inactivityThreshold: savedThreshold ?? PrunePolicy.default.inactivityThreshold,
            isPaused: defaults.bool(forKey: Key.paused),
            notifyOnPrune: notifyOnPrune,
            exclusions: exclusionRules,
            enabledBrowserIDs: enabledBrowsers
        )
        #if DEBUG
        let savedPollingInterval = defaults.object(forKey: Key.pollingInterval) as? Double
        loadedPolicy.pollingInterval = Self.validatedDebugTiming(
            savedPollingInterval ?? PrunePolicy.default.pollingInterval
        )
        #endif
        self.policy = loadedPolicy
        self.hasCompletedFirstRun = defaults.bool(forKey: Key.firstRunCompleted)
    }

    /// Updates the threshold and persists it immediately for next launch.
    func setThreshold(_ threshold: TimeInterval) {
        policy.inactivityThreshold = threshold
        save()
    }

    /// Marks first-run setup complete so future launches begin tracking without re-prompting.
    func completeFirstRun() {
        guard !hasCompletedFirstRun else { return }
        hasCompletedFirstRun = true
        defaults.set(true, forKey: Key.firstRunCompleted)
    }

    #if DEBUG
    /// Updates the development-only polling interval and persists it locally.
    func setPollingInterval(_ pollingInterval: TimeInterval) {
        policy.pollingInterval = Self.validatedDebugTiming(pollingInterval)
        save()
    }
    #endif

    /// Updates user pause state without mutating the current restore history.
    func setPaused(_ isPaused: Bool) {
        policy.isPaused = isPaused
        save()
    }

    /// Updates whether close-cycle notifications fire, persisting immediately for the next prune.
    func setNotifyOnPrune(_ isEnabled: Bool) {
        policy.notifyOnPrune = isEnabled
        save()
    }

    /// Adds one normalized exclusion rule, returning whether it was newly added so callers can give
    /// feedback instead of silently dropping invalid or duplicate input.
    @discardableResult
    func addExclusion(_ rawValue: String) -> Bool {
        guard let rule = DomainExclusionRule(rawValue) else { return false }
        guard !policy.exclusions.contains(rule) else { return false }

        policy.exclusions.append(rule)
        save()
        return true
    }

    /// Removes a matching exclusion rule from the policy.
    func removeExclusion(_ rule: DomainExclusionRule) {
        policy.exclusions.removeAll { $0 == rule }
        save()
    }

    /// Removes every exclusion rule and persists the empty set so a Remove All survives relaunch. Guards
    /// on emptiness so the destructive command never writes an unchanged policy back to defaults.
    func removeAllExclusions() {
        guard !policy.exclusions.isEmpty else { return }
        policy.exclusions.removeAll()
        save()
    }

    /// Enables or disables pruning for one supported browser.
    func setBrowser(_ browserID: BrowserID, enabled: Bool) {
        if enabled {
            policy.enabledBrowserIDs.insert(browserID)
        } else {
            policy.enabledBrowserIDs.remove(browserID)
        }
        save()
    }

    /// Writes the current policy to defaults as simple property-list values.
    private func save() {
        defaults.set(policy.inactivityThreshold, forKey: Key.threshold)
        defaults.set(policy.isPaused, forKey: Key.paused)
        defaults.set(policy.notifyOnPrune, forKey: Key.notifyOnPrune)
        defaults.set(policy.exclusions.map(\.hostSuffix), forKey: Key.exclusions)
        defaults.set(policy.enabledBrowserIDs.map(\.rawValue).sorted(), forKey: Key.enabledBrowsers)
        #if DEBUG
        defaults.set(policy.pollingInterval, forKey: Key.pollingInterval)
        #endif
    }

    #if DEBUG
    /// Clamps debug timing overrides to avoid accidental zero-second timers.
    private static func validatedDebugTiming(_ interval: TimeInterval) -> TimeInterval {
        max(PrunePolicy.minimumDebugTimingInterval, interval)
    }
    #endif
}
