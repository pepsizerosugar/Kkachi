import SwiftUI

/// Lists recently pruned tabs and restoration actions.
struct PrunedHistoryView: View {
    /// Keeps restore disappearance quick enough for a menu while remaining legible.
    private static let historyRemovalAnimation = Animation.easeInOut(duration: 0.18)

    /// Uses store history and restore actions.
    @ObservedObject var store: KkachiStore

    /// Caps restore rows so history stays a preview instead of a manager.
    let rowLimit: Int

    /// Reads the live Reduce Motion preference so restore transitions can collapse to no movement.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tracks which restore row the pointer is over so it can brighten without extra chrome.
    @State private var hoveredRowID: PrunedTab.ID?

    /// Shows restore history as a compact undo surface.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let failure = store.restoreFailure, let tab = failedTab(for: failure) {
                restoreFailureBanner(failure, tab: tab)
            }
            if store.prunedTabs.isEmpty {
                Text("menu.history.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                undoLastCard
                ForEach(recentRows) { tab in
                    row(for: tab)
                }
                if historyOverflow > 0 {
                    Text(KkachiMenuRowText.moreCount(historyOverflow, language: store.preferences.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, KkachiMenuMetrics.rowPadding)
                        .accessibilityIdentifier("menu.history.more")
                }
            }
        }
        .kkachiAnimation(Self.historyRemovalAnimation, value: historyIDs)
    }

    /// Counts pruned tabs retained beyond the preview (the undo card's batch plus visible rows), so
    /// reopenable history past the cap is acknowledged rather than appearing to not exist.
    private var historyOverflow: Int {
        max(0, store.prunedTabs.count - (leadingCardCount + recentRows.count))
    }

    /// Renders the primary undo affordance for the most recent prune. When the last cycle closed several
    /// tabs together, this becomes a single "Reopen all N tabs" action so a multi-tab cleanup is undone
    /// in one tap instead of row by row; otherwise it reopens the single last tab.
    private var undoLastCard: some View {
        Button {
            withAnimation(reduceMotion ? nil : Self.historyRemovalAnimation) {
                if isBatch {
                    _ = store.restoreLastBatch()
                } else {
                    _ = store.restoreLastPrunedTab()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(KkachiMenuPalette.returnBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(undoTitle)
                        .font(.callout.weight(.semibold))
                    Text(undoSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(KkachiRowButtonStyle())
        .padding(KkachiMenuMetrics.cardPadding)
        .background(KkachiMenuPalette.returnBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .help(Text("menu.history.undoLast.help"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(undoTitle))
        .accessibilityHint(Text("menu.history.undoLast.help"))
        .accessibilityIdentifier("menu.history.undoLast")
        .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .trailing))))
    }

    /// True when the most recent close cycle closed more than one tab, so undo should reopen the batch.
    private var isBatch: Bool {
        store.recentBatchCount > 1
    }

    /// Chooses reopen-all vs reopen-last copy for the primary undo affordance.
    private var undoTitle: String {
        isBatch
            ? AppLocalization.format("menu.history.reopenBatch", language: store.preferences.appLanguage, store.recentBatchCount)
            : AppLocalization.string("menu.history.undoLast", language: store.preferences.appLanguage)
    }

    /// Describes what undo will reopen: the batch count, or the single tab's title.
    private var undoSubtitle: String {
        if isBatch {
            return AppLocalization.format("menu.history.batchClosed", language: store.preferences.appLanguage, store.recentBatchCount)
        }
        return store.prunedTabs.first.map { KkachiMenuRowText.title(title: $0.title, url: $0.url) } ?? ""
    }

    /// Renders one restorable history row.
    private func row(for tab: PrunedTab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : Self.historyRemovalAnimation) {
                _ = store.restore(tab)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(KkachiMenuRowText.title(title: tab.title, url: tab.url))
                        .font(.callout)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey(tab.browserNameKey))
                        Text("menu.row.separator")
                            .accessibilityHidden(true)
                        Text(KkachiMenuRowText.subtitle(url: tab.url))
                        Text(tab.prunedAt, style: .relative)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(KkachiRowButtonStyle())
        .padding(KkachiMenuMetrics.rowPadding)
        .background(rowFill(for: tab), in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .onHover { hovering in setHovered(tab, hovering) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hoveredRowID)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("menu.history.row")
        .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .trailing))))
    }

    /// Counts the leading history rows the undo card already represents: the whole most-recent batch
    /// when it closed several tabs, otherwise just the single last tab. Rows below the card skip these so
    /// a batch's tabs are never listed twice (once under "Reopen all N" and again as individual rows).
    private var leadingCardCount: Int {
        isBatch ? store.recentBatchCount : 1
    }

    /// Returns rows below the undo card while respecting the preview limit.
    private var recentRows: [PrunedTab] {
        let remainingSlots = max(0, rowLimit - 1)
        return Array(store.prunedTabs.dropFirst(leadingCardCount).prefix(remainingSlots))
    }

    /// Tracks history identity changes so SwiftUI animates only restore-list updates.
    private var historyIDs: [PrunedTab.ID] {
        store.prunedTabs.map(\.id)
    }

    /// Chooses the hover or resting fill for one restore row.
    private func rowFill(for tab: PrunedTab) -> Color {
        hoveredRowID == tab.id ? KkachiMenuPalette.rowFillHover : KkachiMenuPalette.rowFill
    }

    /// Updates the hovered row, clearing only when the pointer leaves the row it was over.
    private func setHovered(_ tab: PrunedTab, _ hovering: Bool) {
        if hovering {
            hoveredRowID = tab.id
        } else if hoveredRowID == tab.id {
            hoveredRowID = nil
        }
    }
}
