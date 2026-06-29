import SwiftUI

/// Lists live tabs that are eligible for pruning soon.
struct AtRiskListView: View {
    /// Reads live tab risk state and can add exclusions.
    @ObservedObject var store: KkachiStore

    /// Limits visible rows so the menu does not become a tab manager.
    let rowLimit: Int

    /// Remembers the host just protected in this menu session so the row can offer a quick undo.
    @State private var lastProtected: ProtectedUndo?

    /// Tracks which row the pointer is over so it can brighten without becoming a button.
    @State private var hoveredRowID: TrackedTab.ID?

    /// Reads Reduce Motion so the hover fill change is instant when motion is reduced.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pairs a freshly protected host with its rule so undo removes exactly what was added.
    private struct ProtectedUndo: Equatable {
        let host: String
        let rule: DomainExclusionRule
    }

    /// Creates a compact at-risk preview for the menu home.
    init(store: KkachiStore, rowLimit: Int) {
        self.store = store
        self.rowLimit = rowLimit
    }

    /// Shows a compact queue so users can understand what will happen next.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastProtected {
                protectedUndoRow(lastProtected)
            }
            if store.atRiskTabs.isEmpty {
                if lastProtected == nil {
                    Text("menu.atRisk.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(visibleTabs) { tab in
                    row(for: tab)
                }
                if overflowCount > 0 {
                    moreRow(overflowCount)
                }
            }
        }
    }

    /// Returns only the rows that fit in the menu preview.
    private var visibleTabs: [TrackedTab] {
        Array(store.atRiskTabs.prefix(rowLimit))
    }

    /// Counts at-risk tabs hidden beyond the preview so the list can admit it is a subset rather than
    /// silently implying only `rowLimit` tabs are queued.
    private var overflowCount: Int {
        max(0, store.atRiskTabs.count - visibleTabs.count)
    }

    /// Shows a quiet "+N more" line so the true queue size is honest at a glance.
    private func moreRow(_ count: Int) -> some View {
        Text(KkachiMenuRowText.moreCount(count))
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, KkachiMenuMetrics.rowPadding)
            .accessibilityIdentifier("menu.atRisk.more")
    }


    /// Renders one at-risk row with a fast protect action.
    private func row(for tab: TrackedTab) -> some View {
        HStack(spacing: 8) {
            revealButton(for: tab)
            VStack(alignment: .leading, spacing: 2) {
                Text(KkachiMenuRowText.title(title: tab.title, url: tab.url))
                    .font(.callout)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(tab.browserNameKey))
                    Text("menu.row.separator")
                        .accessibilityHidden(true)
                    Text(tab.hostLabel)
                        .truncationMode(.middle)
                    if tab.isAutoCloseBlocked {
                        // The tab is overdue but Kkachi could not close it, so say so honestly instead of
                        // claiming "정리 중" (cleaning now) for a tab it has actually given up on.
                        Text("menu.atRisk.blocked")
                            .layoutPriority(1)
                            .help(Text("menu.atRisk.blocked.help"))
                    } else if let pruneAt = tab.pruneAt {
                        if pruneAt <= Date() {
                            Text("menu.atRisk.prunesNow")
                                .layoutPriority(1)
                        } else {
                            Text("menu.atRisk.prunes")
                                .layoutPriority(1)
                            Text(pruneAt, style: .relative)
                                .layoutPriority(1)
                        }
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            // Combine only the text into one VoiceOver phrase ("Chrome, naver.com, prunes in 5 minutes")
            // while the reveal/protect buttons stay separate actionable elements.
            .accessibilityElement(children: .combine)
            Spacer()
            protectButton(for: tab)
        }
        .padding(KkachiMenuMetrics.rowPadding)
        .background(rowFill(for: tab), in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .onHover { hovering in setHovered(tab, hovering) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hoveredRowID)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu.atRisk.row")
    }

    /// Protects the site when the user recognizes it as intentionally long-lived.
    private func protectButton(for tab: TrackedTab) -> some View {
        Button {
            if let rule = store.protect(tab.hostLabel) {
                lastProtected = ProtectedUndo(host: tab.hostLabel, rule: rule)
            }
        } label: {
            Label("menu.atRisk.protect.label", systemImage: "shield")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .help(Text("menu.atRisk.protect.help"))
        .accessibilityLabel(Text(KkachiMenuRowText.hostScopedLabel("menu.atRisk.protect.a11yLabel", host: tab.hostLabel)))
        .accessibilityHint(Text("menu.atRisk.protect.help"))
        .accessibilityIdentifier("menu.atRisk.protect")
    }

    /// Shows a quiet confirmation with one-tap undo right after a site is protected, keeping the
    /// permanent exclusion reversible without nagging or a modal dialog.
    private func protectedUndoRow(_ protected: ProtectedUndo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.secondary)
            Text("menu.atRisk.protected.label")
                .font(.callout)
            Text(protected.host)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("menu.atRisk.protected.undo") {
                store.removeExclusion(protected.rule)
                lastProtected = nil
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("menu.atRisk.protected.undo")
        }
        .padding(KkachiMenuMetrics.rowPadding)
        .background(KkachiMenuPalette.rowFill, in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu.atRisk.protected")
    }

    /// Chooses the hover or resting fill for one at-risk row.
    private func rowFill(for tab: TrackedTab) -> Color {
        hoveredRowID == tab.id ? KkachiMenuPalette.rowFillHover : KkachiMenuPalette.rowFill
    }

    /// Updates the hovered row, clearing only when the pointer leaves the row it was over.
    private func setHovered(_ tab: TrackedTab, _ hovering: Bool) {
        if hovering {
            hoveredRowID = tab.id
        } else if hoveredRowID == tab.id {
            hoveredRowID = nil
        }
    }

}
