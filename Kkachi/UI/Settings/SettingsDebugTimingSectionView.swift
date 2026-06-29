#if DEBUG
import SwiftUI

/// Provides development-only timing controls for live pruning validation.
struct SettingsDebugTimingSectionView: View {
    /// Observes store state so applied timings stay synchronized with the tracker.
    @ObservedObject var store: KkachiStore

    /// Holds the editable pruning threshold in whole seconds.
    @State private var thresholdSecondsText: String

    /// Holds the editable browser polling interval in whole seconds.
    @State private var pollingSecondsText: String

    /// Identifies the debug pruning threshold text field for UI automation.
    private static let thresholdInputIdentifier = ["settings", "debug", "thresholdSeconds"].joined(separator: ".")

    /// Identifies the debug polling interval text field for UI automation.
    private static let pollingInputIdentifier = ["settings", "debug", "pollingSeconds"].joined(separator: ".")

    /// Creates the section with text fields seeded from the current policy.
    init(store: KkachiStore) {
        self.store = store
        _thresholdSecondsText = State(initialValue: Self.secondsText(for: store.preferences.policy.inactivityThreshold))
        _pollingSecondsText = State(initialValue: Self.secondsText(for: store.preferences.policy.pollingInterval))
    }

    /// Renders compact timing controls inside the existing Settings form.
    var body: some View {
        Section("settings.debugTiming.section") {
            timingRow(
                titleKey: "settings.debugTiming.threshold",
                text: $thresholdSecondsText,
                identifier: Self.thresholdInputIdentifier
            )
            timingRow(
                titleKey: "settings.debugTiming.polling",
                text: $pollingSecondsText,
                identifier: Self.pollingInputIdentifier
            )
            Button("settings.debugTiming.apply") {
                applyTiming()
            }
            .accessibilityIdentifier("settings.debug.applyTiming")
        }
    }

    /// Builds one numeric seconds row with a stable automation identifier.
    private func timingRow(titleKey: LocalizedStringKey, text: Binding<String>, identifier: String) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            TextField(titleKey, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 96)
                .accessibilityIdentifier(identifier)
            Text("settings.debugTiming.seconds")
                .foregroundStyle(.secondary)
        }
    }

    /// Applies sanitized values to the same policy path used by normal Settings controls.
    private func applyTiming() {
        let threshold = parsedSeconds(from: thresholdSecondsText, fallback: store.preferences.policy.inactivityThreshold)
        let polling = parsedSeconds(from: pollingSecondsText, fallback: store.preferences.policy.pollingInterval)

        store.setThreshold(threshold)
        store.setPollingInterval(polling)
        thresholdSecondsText = Self.secondsText(for: threshold)
        pollingSecondsText = Self.secondsText(for: polling)
    }

    /// Parses whole-second input and clamps it to the debug minimum.
    private func parsedSeconds(from text: String, fallback: TimeInterval) -> TimeInterval {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedSeconds = Int(trimmedText) ?? Int(fallback)
        return TimeInterval(max(Int(PrunePolicy.minimumDebugTimingInterval), parsedSeconds))
    }

    /// Formats policy intervals as whole seconds for the debug text fields.
    private static func secondsText(for interval: TimeInterval) -> String {
        String(Int(interval))
    }
}
#endif
