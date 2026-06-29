import Combine
import Foundation

/// Owns inactivity tracking, timer lifecycle, live summaries, and restore history.
@MainActor
final class TabTracker: NSObject, ObservableObject {
    /// Defines how often the tracker wakes to inspect browser tabs.
    static let pollingInterval: TimeInterval = 60

    /// Lets macOS coalesce timer wake-ups for battery efficiency.
    static let timerTolerance: TimeInterval = timerTolerance(for: pollingInterval)

    /// Mirrors the default policy threshold for legacy compatibility tests.
    static let inactivityThreshold: TimeInterval = PrunePolicy.default.inactivityThreshold

    /// Caps memory use by retaining only the newest history entries.
    static let historyLimit = 30

    /// Publishes newest-first pruned tabs for the menu UI.
    @Published var prunedTabs: [PrunedTab] = []

    /// Publishes the most recent poll cycle that actually closed tabs, so the menu can show a
    /// "Closed N tabs" confirmation with reopen-all. Nil until the first close of the session.
    @Published var lastPruneBatch: PruneBatch?

    /// Publishes a brief true window right after a close so the menu-bar mark and hero can acknowledge
    /// active pruning; cleared by `pruningResetTask` a couple seconds later so it stays a gesture.
    @Published var isPruningInProgress = false

    /// Publishes the most recent restore that could not reopen, for row-level fallback UI.
    @Published var restoreFailure: RestoreFailure?

    /// Publishes live tabs from the most recent successful polling cycle.
    @Published var trackedTabs: [TrackedTab] = []

    /// Publishes aggregate counts for the dashboard header.
    @Published var summary: TrackingSummary = .empty

    /// Publishes localized tracker state without exposing raw diagnostics.
    @Published var status: TrackerStatus = .waitingForBrowser

    /// Publishes one readiness row per supported browser.
    @Published var browserStatuses: [BrowserStatus] = []

    /// Retains the latest developer-facing automation error for debugging.
    var lastErrorDescription: String?

    /// Stores all browser adapters participating in tracking.
    let adapters: [any BrowserAdapter]

    /// Stores persisted user preferences used by polling decisions.
    let preferences: PreferencesStore

    /// Persists restore history through the app-provided durable storage boundary.
    let historyStore: any RestoreHistoryStoring

    /// Observes sleep, wake, launch, and termination without importing AppKit.
    let workspaceNotifications: WorkspaceNotificationSource

    /// Stores adapters by browser ID for restore routing.
    let adapterByID: [BrowserID: any BrowserAdapter]

    /// Stores the currently scheduled polling timer, if any.
    var timer: Timer?

    /// Records the interval the active timer was created with, so a power or thermal change can detect
    /// when a freshly resolved cadence would differ and restart the timer only then.
    var activeTimerInterval: TimeInterval?

    /// Coalesces policy-driven polls so Settings interactions return before scripting begins.
    var pendingPolicyPollTask: Task<Void, Never>?

    /// Tracks when each live tab was last active or first observed inactive.
    var lastActiveDates: [String: Date] = [:]

    /// Stores the currently applied pruning policy for fast polling reads.
    var currentPolicy: PrunePolicy

    /// Prevents duplicate observer registration across repeated starts. Setter stays file-private; the
    /// getter is readable by the scheduling extension so power-driven reschedules can check liveness.
    private(set) var isStarted = false

    /// Records sleep state so wake notifications decide whether to resume.
    var isSystemSleeping = false

    /// Records display-sleep state so polling stands down while the user is away with the screen off — a
    /// major battery win, since no Apple Events fire during display sleep — and resumes on screen wake.
    var isDisplayAsleep = false

    /// True when polling should stand down for dormancy: system sleep or display sleep. Polling, status,
    /// and resume decisions all gate on this so either dormancy source quiets background work identically.
    var isDormant: Bool { isSystemSleeping || isDisplayAsleep }

    /// Browsers whose close failed this session; Kkachi stops trying to prune them until relaunch.
    var closeFailedBrowsers: Set<BrowserID> = []

    /// Posts the optional "Closed N tabs" system notification. Nil in tests and under XCUITest so unit
    /// runs never touch UNUserNotificationCenter; production assigns a real notifier after launch. Held
    /// strongly here because UNUserNotificationCenter only keeps a weak delegate.
    var pruneNotifier: (any PruneNotifying)?

    /// Shares one id across every tab closed in the current `evaluate()` cycle; lazily created on the
    /// first close so quiet cycles allocate nothing. Reset at the start of each cycle, and read by
    /// `finishPruneCycle` to gather the cycle's closed tabs from the (already memory-capped) history.
    var activeBatchID: UUID?

    /// Clears `isPruningInProgress` after the brief acknowledgement window; cancelled and rescheduled
    /// when back-to-back cycles close tabs so the gesture never flickers.
    var pruningResetTask: Task<Void, Never>?

    /// Injects all browser, persistence, notification, and user-notification dependencies.
    init(
        adapters: [any BrowserAdapter],
        preferences: PreferencesStore,
        historyStore: any RestoreHistoryStoring,
        workspaceNotifications: WorkspaceNotificationSource,
        pruneNotifier: (any PruneNotifying)? = nil
    ) {
        self.adapters = adapters
        self.adapterByID = Dictionary(uniqueKeysWithValues: adapters.map { ($0.descriptor.id, $0) })
        self.preferences = preferences
        self.historyStore = historyStore
        self.currentPolicy = preferences.policy
        self.workspaceNotifications = workspaceNotifications
        self.pruneNotifier = pruneNotifier
        super.init()
        self.prunedTabs = historyStore.load()
        refreshBrowserStatuses(probe: false)
    }

    func start() {
        guard !isStarted else {
            KkachiDebugLog.tracking("tracker start ignored alreadyStarted=true")
            return
        }

        KkachiDebugLog.tracking("tracker start \(KkachiDebugLog.policyContext(currentPolicy))")
        isStarted = true
        installObservers()
        applyPolicy(preferences.policy, pollImmediately: false)
    }

    func stop() {
        KkachiDebugLog.tracking("tracker stop timerActive=\(timer != nil)")
        cancelScheduledPolicyPoll()
        pruningResetTask?.cancel()
        stopTimer()
        workspaceNotifications.center.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        persistHistory()
        isStarted = false
    }

    func applyPolicy(_ policy: PrunePolicy) {
        applyPolicy(policy, pollImmediately: true)
    }

    /// Applies a changed policy with control over launch-time polling.
    func applyPolicy(_ policy: PrunePolicy, pollImmediately: Bool) {
        let previousPollingInterval = Self.effectivePollingInterval(for: currentPolicy)
        KkachiDebugLog.tracking("apply policy \(KkachiDebugLog.policyContext(policy)) pollImmediately=\(pollImmediately) started=\(isStarted)")
        currentPolicy = policy
        refreshBrowserStatuses(probe: false)
        guard isStarted else {
            if policy.isPaused {
                status = .pausedByUser
            } else if status == .pausedByUser {
                status = hasRunnableBrowser() ? .running : .waitingForBrowser
            }
            return
        }
        if policy.isPaused {
            pauseTimer(clearState: false, statusOverride: .pausedByUser)
        } else if hasRunnableBrowser(), !isDormant {
            if timer != nil, Self.effectivePollingInterval(for: policy) != previousPollingInterval {
                stopTimer()
            }
            resumeTimer(pollImmediately: false)
            if pollImmediately {
                schedulePolicyPoll()
            }
        } else {
            pauseTimer(clearState: true, statusOverride: nil)
        }
    }

}
