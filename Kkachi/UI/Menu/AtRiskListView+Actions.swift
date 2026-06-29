import SwiftUI

/// Row-level reveal action and text helpers for the at-risk queue, split out of AtRiskListView to keep
/// that view under the file-length limit. These touch only the shared store and pure tab fields, so the
/// protect/hover state stays private to the main view.
extension AtRiskListView {
    /// Opens the tab in its browser so review happens in the right context.
    func revealButton(for tab: TrackedTab) -> some View {
        Button {
            store.reveal(tab)
        } label: {
            Label("menu.atRisk.reveal.label", systemImage: "globe")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .help(Text("menu.atRisk.reveal.help"))
        // Names the tab so each repeated icon button is self-describing under VoiceOver (WCAG 2.4.6),
        // instead of a wall of identical "Show in browser" stops with no way to tell rows apart.
        .accessibilityLabel(Text(KkachiMenuRowText.hostScopedLabel("menu.atRisk.reveal.a11yLabel", host: tab.hostLabel)))
        .accessibilityHint(Text("menu.atRisk.reveal.help"))
        .accessibilityIdentifier("menu.atRisk.reveal")
    }
}
