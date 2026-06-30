import SwiftUI

/// Lets users choose how often Kkachi checks browsers without exposing developer-only timing controls.
struct SettingsPollingIntervalField: View {
    /// Observes store state so applied cadence stays synchronized with the tracker.
    @ObservedObject var store: KkachiStore

    /// Holds the editable polling interval in whole minutes.
    @State private var minutesText: String

    /// Identifies the polling field for UI automation.
    private static let inputIdentifier = ["settings", "polling", "minutes"].joined(separator: ".")

    /// Creates the field with text seeded from the current policy.
    init(store: KkachiStore) {
        self.store = store
        _minutesText = State(initialValue: Self.minutesText(for: store.preferences.policy.pollingInterval))
    }

    /// Renders one compact row in the existing pruning section.
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("settings.polling.title")
                Text("settings.polling.caption")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField("", text: $minutesText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(Text("settings.polling.title"))
                .accessibilityIdentifier(Self.inputIdentifier)
                .onSubmit(applyMinutes)
                .onChange(of: minutesText, perform: { _ in applyMinutes() })
            Text("settings.polling.minutes")
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    /// Applies sanitized minute input through the same policy path as the rest of Settings.
    private func applyMinutes() {
        let interval = Self.interval(from: minutesText, fallback: store.preferences.policy.pollingInterval)
        guard store.preferences.policy.pollingInterval != interval else { return }
        store.setPollingInterval(interval)
        minutesText = Self.minutesText(for: interval)
    }

    /// Parses whole-minute input and clamps it to the public Settings range.
    private static func interval(from text: String, fallback: TimeInterval) -> TimeInterval {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedMinutes = Int(trimmedText) ?? Int(fallback / 60)
        let lower = Int(PrunePolicy.minimumPollingInterval / 60)
        let upper = Int(PrunePolicy.maximumPollingInterval / 60)
        return TimeInterval(min(upper, max(lower, parsedMinutes)) * 60)
    }

    /// Formats policy intervals as whole minutes for the text field.
    private static func minutesText(for interval: TimeInterval) -> String {
        String(Int(interval / 60))
    }
}
