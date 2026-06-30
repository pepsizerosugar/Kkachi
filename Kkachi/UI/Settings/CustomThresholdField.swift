import SwiftUI

struct CustomThresholdDraft: Equatable {
    static let minimumDuration: TimeInterval = 5 * 60
    static let maximumDuration: TimeInterval = 7 * 24 * 60 * 60

    var amount: Int
    var unit: CustomThresholdUnit

    init(amount: Int, unit: CustomThresholdUnit) {
        self.amount = amount
        self.unit = unit
    }

    init(duration: TimeInterval) {
        let clampedDuration = Self.clampedDuration(duration)
        if clampedDuration >= CustomThresholdUnit.days.seconds,
           clampedDuration.truncatingRemainder(dividingBy: CustomThresholdUnit.days.seconds) == 0 {
            self.init(amount: Int(clampedDuration / CustomThresholdUnit.days.seconds), unit: .days)
        } else if clampedDuration >= CustomThresholdUnit.hours.seconds,
                  clampedDuration.truncatingRemainder(dividingBy: CustomThresholdUnit.hours.seconds) == 0 {
            self.init(amount: Int(clampedDuration / CustomThresholdUnit.hours.seconds), unit: .hours)
        } else {
            self.init(amount: Int((clampedDuration / CustomThresholdUnit.minutes.seconds).rounded()), unit: .minutes)
        }
    }

    var duration: TimeInterval {
        Self.clampedDuration(TimeInterval(unit.clampedAmount(amount)) * unit.seconds)
    }

    func clamped() -> CustomThresholdDraft {
        CustomThresholdDraft(amount: unit.clampedAmount(amount), unit: unit)
    }

    func converted(to newUnit: CustomThresholdUnit) -> CustomThresholdDraft {
        CustomThresholdDraft(amount: newUnit.amount(for: duration), unit: newUnit)
    }

    private static func clampedDuration(_ duration: TimeInterval) -> TimeInterval {
        min(maximumDuration, max(minimumDuration, duration))
    }
}

enum CustomThresholdUnit: String, CaseIterable, Identifiable {
    case minutes
    case hours
    case days

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .minutes:
            return 60
        case .hours:
            return 60 * 60
        case .days:
            return 24 * 60 * 60
        }
    }

    var amountRange: ClosedRange<Int> {
        let lower = Int(ceil(CustomThresholdDraft.minimumDuration / seconds))
        let upper = Int(floor(CustomThresholdDraft.maximumDuration / seconds))
        return lower...upper
    }

    var step: Int {
        self == .minutes ? 5 : 1
    }

    var localizationKey: String {
        switch self {
        case .minutes:
            return "settings.threshold.custom.unit.minutes"
        case .hours:
            return "settings.threshold.custom.unit.hours"
        case .days:
            return "settings.threshold.custom.unit.days"
        }
    }

    var identifier: String { rawValue }

    func clampedAmount(_ amount: Int) -> Int {
        min(amountRange.upperBound, max(amountRange.lowerBound, amount))
    }

    func amount(for duration: TimeInterval) -> Int {
        clampedAmount(Int(ceil(duration / seconds)))
    }
}

struct CustomThresholdField: View {
    @Binding var draft: CustomThresholdDraft

    let language: AppLanguage

    @FocusState private var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text("settings.threshold.custom.label")
                Spacer(minLength: 12)
                TextField("settings.threshold.custom.label", value: amountBinding, format: .number.grouping(.never))
                    .labelsHidden()
                    .focused($isEditing)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { draft = draft.clamped() }
                    .accessibilityIdentifier("settings.threshold.custom.value")
                Picker("settings.threshold.custom.unit", selection: unitBinding) {
                    ForEach(CustomThresholdUnit.allCases) { unit in
                        Text(LocalizedStringKey(unit.localizationKey))
                            .tag(unit)
                            .accessibilityIdentifier("settings.threshold.custom.unit.\(unit.identifier)")
                    }
                }
                .labelsHidden()
                .frame(width: 86)
                .accessibilityIdentifier("settings.threshold.custom.unit")
                Stepper("settings.threshold.custom.adjust", value: amountBinding, in: draft.unit.amountRange, step: draft.unit.step)
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
            if !editing { draft = draft.clamped() }
        }
    }

    private var amountBinding: Binding<Int> {
        Binding(
            get: { draft.amount },
            set: { newAmount in
                var updated = draft
                updated.amount = min(draft.unit.amountRange.upperBound, newAmount)
                draft = updated
            }
        )
    }

    private var unitBinding: Binding<CustomThresholdUnit> {
        Binding(
            get: { draft.unit },
            set: { newUnit in
                draft = draft.converted(to: newUnit)
            }
        )
    }

    private var summary: String {
        let humanized = Duration.seconds(draft.duration)
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated).locale(language.formattingLocale))
        return AppLocalization.format("settings.threshold.custom.summary", language: language, humanized)
    }
}
