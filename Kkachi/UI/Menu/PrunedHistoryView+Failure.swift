import SwiftUI

/// Restore-failure fallback UI for the history list, split out of PrunedHistoryView to keep that view
/// under the file-length limit. Shown only while the failed row is still present, so the banner clears
/// itself once the tab is reopened elsewhere or the history is cleared.
extension PrunedHistoryView {
    /// Finds the still-present history row a restore failure refers to.
    func failedTab(for failure: RestoreFailure) -> PrunedTab? {
        store.prunedTabs.first { $0.id == failure.tabID }
    }

    /// Explains a failed reopen and offers a default-browser fallback plus copy, so the URL is never lost.
    func restoreFailureBanner(_ failure: RestoreFailure, tab: PrunedTab) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(LocalizedStringKey(failure.reason.localizationKey), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("menu.history.openInDefaultBrowser") {
                    store.restoreInDefaultBrowser(tab)
                }
                .accessibilityIdentifier("menu.history.openInDefaultBrowser")
                Button("menu.history.copyURL") {
                    store.copyURL(tab)
                }
                .accessibilityIdentifier("menu.history.copyURL")
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KkachiMenuMetrics.cardPadding)
        .background(KkachiMenuPalette.warningGold.opacity(0.12), in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu.history.restoreFailure")
    }
}
