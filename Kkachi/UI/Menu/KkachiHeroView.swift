import SwiftUI

/// Presents the compact status summary at the top of the menu popover: a clean brand mark beside the
/// current state headline. State is carried by the headline copy and the live menu-bar item, so the
/// hero deliberately omits the earlier perch glyph and status symbol that read as decorative noise.
struct KkachiHeroView: View {
    /// Reads tracker summary and derived home presentation from the app store.
    @ObservedObject var store: KkachiStore

    /// Renders Kkachi as a confident identity mark next to the state headline and detail.
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            observerMark
            VStack(alignment: .leading, spacing: 4) {
                Text("app.menuBar.title")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                headlineText
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(LocalizedStringKey(snapshot.detailKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
        // Speak the same status a sighted user reads — the headline as the label and the detail as its
        // value — instead of substituting a vaguer mood phrase that drops the actionable sentence.
        .accessibilityLabel(headlineText)
        .accessibilityValue(Text(LocalizedStringKey(snapshot.detailKey)))
        .accessibilityIdentifier("menu.dashboard")
    }

    /// Provides the current compact home presentation.
    private var snapshot: KkachiMenuHomeSnapshot {
        store.menuHomeSnapshot
    }

    /// Renders the state headline, interpolating a count when the snapshot carries one (the at-risk state
    /// names how many tabs are closing soon) and otherwise rendering the plain localized key. The counted
    /// headline value must contain a %lld, so String(format:) substitutes the count.
    private var headlineText: Text {
        if let count = snapshot.headlineCount {
            return Text(AppLocalization.format(snapshot.headlineKey, language: store.preferences.appLanguage, count))
        }
        return Text(LocalizedStringKey(snapshot.headlineKey))
    }

    /// Draws the magpie as a monochrome brand mark, matching the menu-bar item's template treatment.
    private var observerMark: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }
}
