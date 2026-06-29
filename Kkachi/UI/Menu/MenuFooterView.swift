import AppKit
import SwiftUI

/// Provides global menu actions that affect app behavior.
struct MenuFooterView: View {
    /// Reads store state for pause visibility while native controls own global app actions.
    @ObservedObject var store: KkachiStore

    /// Renders compact native controls in a predictable footer.
    var body: some View {
        HStack(spacing: 12) {
            SettingsSceneLink {
                Label("menu.footer.settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("menu.footer.settings")

            Spacer()

            if shouldShowPauseAction {
                Button {
                    store.togglePause()
                } label: {
                    Label(LocalizedStringKey(pauseLabelKey), systemImage: pauseIconName)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("menu.footer.pause")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("menu.footer.quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("menu.footer.quit")
        }
        .controlSize(.small)
        .font(.callout)
    }

    /// Avoids repeating the same pause or resume command shown as the primary action.
    private var shouldShowPauseAction: Bool {
        switch store.menuHomeSnapshot.primaryAction {
        case .pause, .resume, .connect:
            return false
        case .reviewQueue, .undoLastPrune, .openBrowser, .retry, .openSettings:
            return true
        }
    }

    /// Chooses pause or resume copy based on current user preference.
    private var pauseLabelKey: String {
        store.preferences.policy.isPaused ? "menu.footer.resume" : "menu.footer.pause"
    }

    /// Chooses a familiar system icon for the pause state action.
    private var pauseIconName: String {
        store.preferences.policy.isPaused ? "play.fill" : "pause.fill"
    }
}
