import AppKit
import Combine
import SwiftUI

/// Owns Kkachi's static menu-bar item while SwiftUI owns the popover content.
@MainActor
final class MenuBarStatusController: NSObject {
    /// Stores the legacy defaults key retained so older UI-test fixtures still reset cleanly.
    static let animationEnabledKey = "mascot.animateIcon"

    /// Stores the legacy defaults key retained while the new branch mark stays static.
    static let expressiveMotionKey = "mascot.expressiveMotion"

    /// Reads app state used to derive mood and dashboard content.
    private let store: KkachiStore

    /// Owns the AppKit status item that can update frames efficiently.
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    /// Hosts the SwiftUI menu dashboard in an AppKit popover.
    private let popover = NSPopover()

    /// Supplies the menu-bar template image for a mood (the mascot still, or the procedural mark).
    private let frameProvider = MascotFrameProvider()

    /// Remembers the last mood rendered into the status item so frequent, unrelated store updates don't
    /// redraw the (static) menu-bar image; only an actual mood change swaps the icon.
    private var lastRenderedMood: KkachiMood?

    /// Retains the Combine subscription for store updates.
    private var cancellables: Set<AnyCancellable> = []

    /// Creates a status controller for the process-lifetime store.
    init(store: KkachiStore) {
        self.store = store
        super.init()
    }

    /// Installs the status item, popover, and observers.
    func start() {
        configureStatusButton()
        configurePopover()
        observeStore()
        applyStatusMark()
    }

    /// Removes timers and the status item before app termination.
    func stop() {
        cancellables.removeAll()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    /// Configures the button that lives in the macOS menu bar.
    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageOnly
        button.toolTip = AppLocalization.string("app.menuBar.title", language: store.preferences.appLanguage)
    }

    /// Configures the SwiftUI popover shown from the menu-bar item.
    private func configurePopover() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: KkachiLocalizedRoot(store: store) {
            MenuView(store: store)
        })
    }

    /// Observes app state changes that affect the mood and its static menu-bar mark.
    private func observeStore() {
        store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                await Task.yield()
                self?.applyStatusMark()
            }
        }
        .store(in: &cancellables)
    }

    /// Opens or closes the SwiftUI dashboard popover.
    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Task { @MainActor [weak self] in self?.store.tracker.refreshNow() }
    }

    /// Builds the status item's label and tooltip: for the alert mood it folds in how many tabs are
    /// about to be pruned, so the glanceable surface answers "how many" and not only "what mood"; other
    /// moods keep their concise phrase since they carry no count to show.
    private func statusItemLabel(for presentation: KkachiMoodPresentation) -> String {
        // Sleep collapses to the paused mood for the mark, but should not announce "paused": say
        // "sleeping" so the always-visible label matches the popover's sleep state and the real system
        // status, not a user pause the user never made.
        let language = store.preferences.appLanguage
        if store.status == .pausedForSleep {
            return AppLocalization.string("menu.mood.sleeping", language: language)
        }
        if presentation.mood == .alert {
            let count = store.summary.atRiskCount
            if count > 0 {
                let key = count == 1 ? "menu.status.atRiskCount.one" : "menu.status.atRiskCount.other"
                return AppLocalization.format(key, language: language, count)
            }
        }
        return AppLocalization.string(presentation.accessibilityKey, language: language)
    }

    /// Refreshes the accessibility copy every update, then swaps the static menu-bar still only when the
    /// mood actually changes. The bird never animates, so the frequent store updates that happen while
    /// nothing visible changed cost a label refresh — never a timer or a per-frame redraw.
    private func applyStatusMark() {
        guard let button = statusItem.button else { return }

        let presentation = store.kkachiMoodPresentation

        let statusLabel = statusItemLabel(for: presentation)
        button.setAccessibilityLabel(statusLabel)
        button.toolTip = statusLabel

        guard presentation.mood != lastRenderedMood else { return }
        lastRenderedMood = presentation.mood
        button.image = frameProvider.image(for: presentation.mood, fallbackSymbolName: presentation.fallbackSymbolName)
    }
}
