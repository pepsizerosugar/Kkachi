import SwiftUI

/// Primes first-run users on what connecting a browser does — and what it never reads — right before
/// the deliberate Connect tap that requests Apple Events access. Keeps the consent moment honest and quiet.
struct FirstRunPrimingView: View {
    /// Shows a compact why / what-read / what-not / where block under the Connect action.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("menu.firstRun.priming.title")
                .font(.callout.weight(.semibold))
            primingRow("checkmark.shield", "menu.firstRun.priming.reads")
            primingRow("xmark.shield", "menu.firstRun.priming.never")
            primingRow("lock.laptopcomputer", "menu.firstRun.priming.local")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KkachiMenuMetrics.cardPadding)
        .background(KkachiMenuPalette.rowFill, in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("menu.context.firstRun")
    }

    /// Renders one quiet reassurance line with a leading symbol.
    private func primingRow(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
