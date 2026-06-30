import SwiftUI

/// Lets the user dial an arbitrary cleanup delay in minutes when no quick preset fits their workflow.
/// The parent owns persistence and range clamping; this view presents the editable minute value, a live
/// hour/minute summary that keeps the custom row on the same scale as the presets, and reconciles the
/// field back into range when editing ends so the display never disagrees with the persisted threshold.
struct CustomThresholdField: View {
    /// Two-way minute value shared with the parent so edits drive the persisted threshold.
    @Binding var minutes: Int

    /// Inclusive minute bounds the committed value must respect.
    let range: ClosedRange<Int>

    /// Increment applied by the stepper's plus and minus controls.
    let step: Int

    /// Language used for summary strings that require manual formatting.
    let language: AppLanguage

    /// Tracks text-field focus so an out-of-range entry is clamped the moment editing ends, not only on
    /// Return — macOS does not deliver onSubmit for click-away or Tab.
    @FocusState private var isEditing: Bool

    /// Renders a labeled minute field, a stepper, and a humanized summary of the chosen delay.
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text("settings.threshold.custom.label")
                Spacer(minLength: 12)
                TextField("settings.threshold.custom.label", value: $minutes, format: .number.grouping(.never))
                    .labelsHidden()
                    .focused($isEditing)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { minutes = clamped(minutes) }
                    .accessibilityIdentifier("settings.threshold.custom.value")
                Text("settings.threshold.custom.unit")
                    .foregroundStyle(.secondary)
                Stepper("settings.threshold.custom.adjust", value: $minutes, in: range, step: step)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.threshold.custom.stepper")
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.threshold.custom.summary")
        }
        .onChange(of: isEditing) { editing in
            if !editing { minutes = clamped(minutes) }
        }
    }

    /// Reads the current delay back on the same hour/minute scale the presets use, localized by the
    /// system so "90" minutes reads as "1h 30m" / "1시간 30분" instead of a bare minute count.
    private var summary: String {
        let humanized = Duration.seconds(clamped(minutes) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(language.formattingLocale))
        return AppLocalization.format("settings.threshold.custom.summary", language: language, humanized)
    }

    /// Constrains a minute value to the allowed range so commits never persist an unsafe delay.
    private func clamped(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
