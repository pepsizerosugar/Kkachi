import AppKit
import SwiftUI

/// Opens the app Settings window from menu-bar surfaces.
struct SettingsSceneLink<Label: View>: View {
    /// Builds caller-owned label content so each menu location keeps its own copy and icon.
    private let label: () -> Label

    /// Creates a Settings opener with the caller's visible label.
    init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    /// Uses a plain button so AppKit can prepare foreground activation before showing Settings.
    var body: some View {
        Button {
            openSettingsWindow()
        } label: {
            label()
        }
    }

    /// Delegates Settings presentation to the app lifecycle owner that can manage activation policy.
    private func openSettingsWindow() {
        guard let appDelegate = AppDelegate.shared ?? NSApp.delegate as? AppDelegate else { return }

        appDelegate.openSettingsWindow()
    }
}
