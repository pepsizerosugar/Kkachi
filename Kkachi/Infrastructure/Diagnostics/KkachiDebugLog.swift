import Foundation

#if DEBUG
import OSLog
#endif

/// Centralizes DEBUG-only diagnostics without changing release logging behavior.
enum KkachiDebugLog {
    #if DEBUG
    /// Identifies Kkachi log rows in Console.app predicates.
    private static let subsystem = "io.github.pepsizerosugar.Kkachi"

    /// Records tracker lifecycle, policy, and timer diagnostics.
    private static let trackingLogger = Logger(subsystem: subsystem, category: "tracking")

    /// Records browser readiness and adapter boundary diagnostics.
    private static let browserLogger = Logger(subsystem: subsystem, category: "browser")

    /// Records tab eligibility, expiration, and pruning decisions.
    private static let pruningLogger = Logger(subsystem: subsystem, category: "pruning")

    /// Records low-level ScriptingBridge lookup and command diagnostics.
    private static let scriptingLogger = Logger(subsystem: subsystem, category: "scripting")
    #endif

    /// Logs tracker lifecycle and scheduling details in DEBUG builds.
    static func tracking(_ message: @autoclosure () -> String) {
        #if DEBUG
        let renderedMessage = message()
        trackingLogger.debug("\(renderedMessage, privacy: .public)")
        #endif
    }

    /// Logs browser adapter and capability details in DEBUG builds.
    static func browser(_ message: @autoclosure () -> String) {
        #if DEBUG
        let renderedMessage = message()
        browserLogger.debug("\(renderedMessage, privacy: .public)")
        #endif
    }

    /// Logs pruning decisions and outcomes in DEBUG builds.
    static func pruning(_ message: @autoclosure () -> String) {
        #if DEBUG
        let renderedMessage = message()
        pruningLogger.debug("\(renderedMessage, privacy: .public)")
        #endif
    }

    /// Logs ScriptingBridge operations in DEBUG builds.
    static func scripting(_ message: @autoclosure () -> String) {
        #if DEBUG
        let renderedMessage = message()
        scriptingLogger.debug("\(renderedMessage, privacy: .public)")
        #endif
    }

    /// Formats tab identity without logging full URLs or titles.
    static func tabContext(_ tab: BrowserTabSnapshot) -> String {
        let host = tab.url.host ?? "unknown-host"
        return "browser=\(tab.identity.browserID.rawValue) window=\(tab.identity.windowID) tab=\(tab.identity.tabID) host=\(host)"
    }

    /// Formats policy timing in seconds for concise diagnostics.
    static func policyContext(_ policy: PrunePolicy) -> String {
        #if DEBUG
        let pollingSeconds = Int(max(PrunePolicy.minimumDebugTimingInterval, policy.pollingInterval))
        return "thresholdSeconds=\(Int(policy.inactivityThreshold)) pollingSeconds=\(pollingSeconds) paused=\(policy.isPaused)"
        #else
        return "thresholdSeconds=\(Int(policy.inactivityThreshold)) paused=\(policy.isPaused)"
        #endif
    }
}
