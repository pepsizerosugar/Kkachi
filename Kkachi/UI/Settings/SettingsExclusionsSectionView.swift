import SwiftUI

/// Owns the Protected Sites Settings group: a counted header, a forgiving add field, a scannable
/// alphabetical list, an optional filter for long lists, quick removal, and a footer that explains what
/// "protected" means. Extracted from SettingsView and split across an add-field and a row view so each
/// file stays under the length limit, matching the sibling SettingsXxxSectionView pattern.
struct SettingsExclusionsSectionView: View {
    /// Shared store whose exclusion rules these controls read and mutate.
    @ObservedObject var store: KkachiStore

    /// Live filter text, shown only once the list is long enough to need scanning help.
    @State private var filterText = ""

    /// Drives the destructive Remove All confirmation, mirroring the privacy Clear History flow.
    @State private var isConfirmingClearAll = false

    /// Row count past which the filter field appears, keeping the common short-list case calm.
    private static let filterThreshold = 8

    /// Composes the section: counted header, add field, optional filter, the rows, Remove All, footer.
    var body: some View {
        Section {
            SettingsExclusionAddField(store: store)
            if showFilter { filterField }
            rows
            if !exclusions.isEmpty { clearAllButton }
        } header: {
            header
        } footer: {
            Text("settings.exclusions.footer")
                .foregroundStyle(.secondary)
        }
    }

    /// Current rules in stored (insertion) order; the single source the subviews read.
    private var exclusions: [DomainExclusionRule] {
        store.preferences.policy.exclusions
    }

    /// Title plus a live protected-count so the list size is visible at a glance (hidden at zero).
    private var header: some View {
        HStack {
            Text("settings.exclusions.section")
            Spacer()
            if !exclusions.isEmpty {
                Text(AppLocalization.format("settings.exclusions.count", language: store.preferences.appLanguage, exclusions.count))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// True once the list is long enough that scanning benefits from a filter.
    private var showFilter: Bool {
        exclusions.count > Self.filterThreshold
    }

    /// A plain in-section filter field. `.searchable` is deliberately avoided: on macOS it attaches a
    /// field to the window toolbar, not inside a Form section.
    private var filterField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("settings.exclusions.filter.placeholder", text: $filterText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("settings.exclusions.filter")
        }
    }

    /// Rules sorted A→Z for scannability; display-only, so persisted insertion order is untouched.
    private var sortedRules: [DomainExclusionRule] {
        exclusions.sorted { $0.hostSuffix < $1.hostSuffix }
    }

    /// Sorted rules narrowed by the live filter when it is shown and non-empty.
    private var visibleRules: [DomainExclusionRule] {
        guard showFilter, !filterText.isEmpty else { return sortedRules }
        return sortedRules.filter { $0.hostSuffix.localizedCaseInsensitiveContains(filterText) }
    }

    /// The list body: a welcoming empty state, a no-match note when the filter excludes everything, or
    /// the rows themselves.
    @ViewBuilder private var rows: some View {
        if exclusions.isEmpty {
            Text("settings.exclusions.empty")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if visibleRules.isEmpty {
            Text("settings.exclusions.filter.empty")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(visibleRules) { rule in
                SettingsExclusionRowView(store: store, rule: rule)
            }
        }
    }

    /// Destructive clear-all for the "several at once" case, guarded by a confirmation exactly like the
    /// privacy Clear History action so an accidental tap never wipes the list.
    private var clearAllButton: some View {
        Button("settings.exclusions.clearAll", role: .destructive) {
            isConfirmingClearAll = true
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("settings.exclusions.clearAll")
        .confirmationDialog(
            "settings.exclusions.clearAll.confirm.title",
            isPresented: $isConfirmingClearAll,
            titleVisibility: .visible
        ) {
            Button("settings.exclusions.clearAll.confirm.button", role: .destructive) {
                store.removeAllExclusions()
            }
            .accessibilityIdentifier("settings.exclusions.clearAll.confirm")
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.exclusions.clearAll.confirm.message")
        }
    }
}
