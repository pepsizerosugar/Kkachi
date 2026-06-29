import Foundation
import OSLog

/// Always-compiled `os_signpost` instrumentation for the polling hot path. Unlike `KkachiDebugLog`
/// (which is DEBUG-only), these signposts ship in every build — including Release — because their entire
/// purpose is to make Kkachi's background work measurable in Instruments (the `os_signpost` and Time
/// Profiler instruments, the Energy gauge's points-of-interest track) on the same binary users run.
///
/// Signposts are near-zero cost when no Instruments recording is attached: `OSSignposter` checks whether
/// its log is enabled and skips the work otherwise, so leaving them in costs nothing in normal use while
/// giving "how often do we poll" and "how long does each browser fetch take" answers on demand. Filter by
/// the `io.github.pepsizerosugar.Kkachi` subsystem / `poll` category in Instruments to isolate them.
enum KkachiSignpost {
    /// Identifies Kkachi signpost rows in Instruments, matching the `KkachiDebugLog` subsystem.
    private static let subsystem = "io.github.pepsizerosugar.Kkachi"

    /// Emits poll-cycle and per-browser fetch intervals; one shared instance keeps signpost IDs coherent.
    private static let signposter = OSSignposter(subsystem: subsystem, category: "poll")

    /// Marks the start of one polling cycle. Pair the returned state with `endPollCycle` so Instruments
    /// renders a single interval per cycle — its width is the main-actor time the cycle held.
    static func beginPollCycle() -> OSSignpostIntervalState {
        signposter.beginInterval("pollCycle")
    }

    /// Closes the poll-cycle interval opened by `beginPollCycle`.
    static func endPollCycle(_ state: OSSignpostIntervalState) {
        signposter.endInterval("pollCycle", state)
    }

    /// Marks the start of one browser's tab fetch, tagging the interval with the browser id so multiple
    /// browsers are distinguishable in the trace. Each fetch gets a fresh signpost id.
    static func beginFetch(browser: String) -> OSSignpostIntervalState {
        signposter.beginInterval("fetchTabs", id: signposter.makeSignpostID(), "browser=\(browser)")
    }

    /// Closes the fetch interval opened by `beginFetch`, recording how many tabs the browser returned.
    static func endFetch(_ state: OSSignpostIntervalState, tabCount: Int) {
        signposter.endInterval("fetchTabs", state, "tabCount=\(tabCount)")
    }
}
