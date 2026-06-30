import Foundation

/// Owns polling timer mechanics and deferred policy-triggered polling.
@MainActor
extension TabTracker {
    /// Delays policy-triggered polling long enough for Settings controls to finish responding.
    private static let policyPollDelayNanoseconds: UInt64 = 250_000_000

    /// Returns the timer tolerance for a polling interval while preserving the 10% invariant.
    static func timerTolerance(for interval: TimeInterval) -> TimeInterval {
        interval * 0.1
    }

    /// Resolves the active polling interval. DEBUG honors the user timing override verbatim so tests stay
    /// deterministic; Release widens the chosen cadence under power pressure so background work backs off
    /// exactly when the machine most needs to conserve energy.
    static func effectivePollingInterval(for policy: PrunePolicy) -> TimeInterval {
        let pollingInterval = max(PrunePolicy.minimumPollingInterval, policy.pollingInterval)
        #if DEBUG
        return pollingInterval
        #else
        let info = ProcessInfo.processInfo
        return powerAdjustedInterval(pollingInterval, lowPowerMode: info.isLowPowerModeEnabled, thermalState: info.thermalState)
        #endif
    }

    /// Widens a base polling interval under power pressure. Pure and parameterized so the back-off policy
    /// is unit-testable without toggling real system power state; multipliers compose by taking the
    /// strongest applicable factor rather than stacking, keeping the worst case bounded and predictable.
    static func powerAdjustedInterval(_ base: TimeInterval, lowPowerMode: Bool, thermalState: ProcessInfo.ThermalState) -> TimeInterval {
        var multiplier: Double = 1
        if lowPowerMode { multiplier = max(multiplier, 3) }
        switch thermalState {
        case .serious: multiplier = max(multiplier, 2)
        case .critical: multiplier = max(multiplier, 4)
        default: break
        }
        return base * multiplier
    }

    /// Restarts the polling timer when the power-resolved cadence would now differ — e.g. Low Power Mode
    /// or a thermal change widened the interval. No-ops when paused, dormant, or already on the right
    /// cadence, so a power-state notification never forces an extra off-schedule poll.
    func reapplyPollingCadence() {
        guard isStarted, !currentPolicy.isPaused, !isDormant, hasRunnableBrowser() else { return }
        let resolvedInterval = Self.effectivePollingInterval(for: currentPolicy)
        guard timer != nil, resolvedInterval != activeTimerInterval else { return }
        KkachiDebugLog.tracking("timer reschedule reason=powerConditions intervalSeconds=\(Int(resolvedInterval))")
        let priorStatus = status
        stopTimer()
        resumeTimer(pollImmediately: false)
        status = priorStatus
    }

    /// Starts the coalesced timer and optionally schedules one near-term poll.
    func resumeTimer(pollImmediately: Bool = true) {
        guard timer == nil else {
            if pollImmediately {
                schedulePolicyPoll()
            }
            return
        }

        let pollingInterval = Self.effectivePollingInterval(for: currentPolicy)
        KkachiDebugLog.tracking("timer resume intervalSeconds=\(Int(pollingInterval)) pollImmediately=\(pollImmediately)")
        let newTimer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollOnce()
            }
        }
        newTimer.tolerance = Self.timerTolerance(for: pollingInterval)
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        activeTimerInterval = pollingInterval
        if pollImmediately {
            schedulePolicyPoll()
        } else {
            status = .running
        }
    }

    /// Stops polling and optionally clears live tab state that no longer applies.
    func pauseTimer(clearState: Bool, statusOverride: TrackerStatus?) {
        KkachiDebugLog.tracking("timer pause clearState=\(clearState) statusOverride=\(String(describing: statusOverride))")
        cancelScheduledPolicyPoll()
        stopTimer()
        if clearState {
            lastActiveDates.removeAll()
            trackedTabs.removeAll()
            summary = .empty
        }
        refreshBrowserStatuses(probe: false)
        status = statusOverride ?? (isDormant ? .pausedForSleep : .waitingForBrowser)
    }

    /// Invalidates the active timer without altering visible tracker state.
    func stopTimer() {
        KkachiDebugLog.tracking("timer stop active=\(timer != nil)")
        timer?.invalidate()
        timer = nil
        activeTimerInterval = nil
    }

    /// Cancels a pending policy poll so paused or stopped trackers do not poll later.
    func cancelScheduledPolicyPoll() {
        KkachiDebugLog.tracking("policy poll cancel pending=\(pendingPolicyPollTask != nil)")
        pendingPolicyPollTask?.cancel()
        pendingPolicyPollTask = nil
    }

    /// Coalesces rapid policy changes into one deferred polling pass.
    func schedulePolicyPoll() {
        KkachiDebugLog.tracking("policy poll schedule delayNanoseconds=\(Self.policyPollDelayNanoseconds)")
        pendingPolicyPollTask?.cancel()
        pendingPolicyPollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.policyPollDelayNanoseconds)
            self?.runScheduledPolicyPoll()
        }
    }

    /// Runs a deferred poll only while the tracker still owns an active timer.
    private func runScheduledPolicyPoll() {
        guard !Task.isCancelled else { return }

        KkachiDebugLog.tracking("policy poll run timerActive=\(timer != nil)")
        pendingPolicyPollTask = nil
        guard timer != nil else { return }

        pollOnce()
    }
}
