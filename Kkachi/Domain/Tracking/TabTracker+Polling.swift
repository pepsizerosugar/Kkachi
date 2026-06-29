import Foundation

/// Owns the polling cycle and its time budget so one cluster of stalled browsers cannot block the
/// main actor: when a cycle runs long, the remaining browsers are deferred to the next tick.
@MainActor
extension TabTracker {
    /// Caps the wall-clock time spent fetching browsers in a single cycle. With the per-browser
    /// timeout this bounds worst-case main-actor blocking instead of letting N stalls add up serially.
    static let pollCycleBudget: TimeInterval = 8

    /// Runs one polling cycle; tests call this directly with controlled dates and an optional clock.
    /// `now` is the logical poll time used for prune decisions; `clock` measures real elapsed time so
    /// the budget can defer the remaining browsers when a cycle stalls.
    func pollOnce(now: Date = Date(), clock: () -> Date = Date.init) {
        KkachiDebugLog.tracking("poll start now=\(now.timeIntervalSince1970) \(KkachiDebugLog.policyContext(currentPolicy))")
        guard !currentPolicy.isPaused else {
            KkachiDebugLog.tracking("poll skipped reason=pausedByUser")
            status = .pausedByUser
            return
        }
        guard !isDormant else {
            KkachiDebugLog.tracking("poll skipped reason=pausedForDormancy")
            status = .pausedForSleep
            return
        }

        let activeAdapters = runnableAdapters()
        KkachiDebugLog.tracking("poll runnableBrowsers=\(activeAdapters.map { $0.descriptor.id.rawValue }.joined(separator: ",")) count=\(activeAdapters.count)")
        guard !activeAdapters.isEmpty else {
            KkachiDebugLog.tracking("poll skipped reason=noRunnableBrowser")
            pauseTimer(clearState: true, statusOverride: nil)
            return
        }
        var collectedTabs: [BrowserTabSnapshot] = []
        var hadPollingError = false
        var succeededCount = 0
        let cycleStart = clock()
        let pollSignpost = KkachiSignpost.beginPollCycle()
        defer { KkachiSignpost.endPollCycle(pollSignpost) }
        for adapter in activeAdapters {
            if clock().timeIntervalSince(cycleStart) > Self.pollCycleBudget {
                KkachiDebugLog.tracking("poll budget exceeded; deferring remaining browsers to next cycle")
                break
            }
            let fetchSignpost = KkachiSignpost.beginFetch(browser: adapter.descriptor.id.rawValue)
            do {
                let adapterTabs = try adapter.fetchTabs()
                KkachiSignpost.endFetch(fetchSignpost, tabCount: adapterTabs.count)
                KkachiDebugLog.browser("fetch success browser=\(adapter.descriptor.id.rawValue) tabCount=\(adapterTabs.count)")
                updateStatus(for: adapter, automationState: .ready, error: nil, installed: true, running: true)
                collectedTabs.append(contentsOf: adapterTabs)
                succeededCount += 1
            } catch {
                KkachiSignpost.endFetch(fetchSignpost, tabCount: 0)
                hadPollingError = true
                KkachiDebugLog.browser("fetch failed browser=\(adapter.descriptor.id.rawValue) error=\(String(describing: error))")
                updateStatus(for: adapter, automationState: automationFailureState(for: error), error: error)
                lastErrorDescription = String(describing: error)
            }
        }

        let hadPruneError = evaluate(collectedTabs, now: now)
        KkachiDebugLog.tracking("poll finish collectedTabs=\(collectedTabs.count) succeeded=\(succeededCount) hadPollingError=\(hadPollingError) hadPruneError=\(hadPruneError)")
        resolvePollStatus(succeededCount: succeededCount, hadPollingError: hadPollingError, hadPruneError: hadPruneError)
    }

    /// Forces one immediate poll in response to direct user interaction — opening the menu popover. The
    /// scheduled timer only refreshes on its cadence (60s by default), so without this the menu would
    /// show the last snapshot: a tab the user just closed by hand still listed, or a countdown that has
    /// already elapsed frozen on "정리 중". Polling on open makes the menu reflect reality the instant it
    /// is shown. Opening the popover is also unambiguous proof the user is present at an awake display, so
    /// a stranded dormancy flag (e.g. a missed `screensDidWake` on clamshell/external-display setups) is
    /// cleared and the timer re-established first — making the menu the always-available manual recovery
    /// path when background polling has stalled. No-ops while the user has explicitly paused pruning,
    /// which must stay paused until the user resumes. Callers should dispatch this off the popover
    /// presentation (a slow synchronous browser fetch must never block the menu from appearing).
    func refreshNow() {
        guard isStarted, !currentPolicy.isPaused else { return }
        if isDormant {
            isSystemSleeping = false
            isDisplayAsleep = false
            applyPolicy(currentPolicy, pollImmediately: false)
        }
        pollOnce()
    }
}
