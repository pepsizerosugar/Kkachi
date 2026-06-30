import SwiftUI

/// Renders one protected-site row in Settings: a shield, the host suffix, and a quiet remove control
/// that brightens on hover. Lives in its own file so the section view stays under the file-length limit.
///
/// The remove control follows the verified AtRiskListView idiom — it is ALWAYS present at a resting
/// strength and only shifts secondary → red on hover (never opacity 0). That keeps it hittable for the
/// pointer, the keyboard, VoiceOver, and the existing `settings.exclusions.remove` UI test, which clicks
/// it without hovering. Removal is also reachable via right-click and the Delete key on a focused row.
struct SettingsExclusionRowView: View {
    /// Shared store whose exclusion list this row mutates on remove.
    @ObservedObject var store: KkachiStore

    /// The rule this row displays and can remove; its `hostSuffix` is the stable list identity.
    let rule: DomainExclusionRule

    /// Tracks pointer hover so the row tint and the trash glyph respond together.
    @State private var isHovered = false

    /// Lays out the shield, host, and remove control with hover, context-menu, and Delete-key removal.
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(rule.hostSuffix)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("settings.exclusions.row")
            Spacer()
            removeButton
        }
        .padding(KkachiMenuMetrics.rowPadding)
        .background(isHovered ? KkachiMenuPalette.rowFillHover : KkachiMenuPalette.rowFill,
                    in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .kkachiAnimation(.easeOut(duration: 0.12), value: isHovered)
        .contextMenu { removeMenuButton }
        .focusable()
        .onDeleteCommand { store.removeExclusion(rule) }
    }

    /// The always-present remove control: secondary at rest, red on hover, opacity unchanged so it stays
    /// hittable for every input path. Tinting the glyph (not the button role) keeps the resting color
    /// under our control instead of the system's destructive red.
    private var removeButton: some View {
        Button {
            store.removeExclusion(rule)
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(isHovered ? Color.red : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help(removeHelp)
        .accessibilityLabel(removeHelp)
        .accessibilityIdentifier("settings.exclusions.remove")
    }

    /// A right-click removal path that does not depend on hover, mirroring the row's primary action.
    private var removeMenuButton: some View {
        Button(role: .destructive) {
            store.removeExclusion(rule)
        } label: {
            Label("settings.exclusions.remove", systemImage: "trash")
        }
    }

    /// Builds the host-named remove label so VoiceOver and the tooltip say exactly which site is removed.
    private var removeHelp: Text {
        Text(AppLocalization.format("settings.exclusions.remove.help", language: store.preferences.appLanguage, rule.hostSuffix))
    }
}
