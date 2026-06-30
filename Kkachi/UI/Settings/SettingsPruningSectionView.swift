import SwiftUI

/// Owns the pruning Settings group: when Kkachi cleans inactive tabs, plus pause and launch-at-login.
/// Extracted from SettingsView so the custom-threshold logic stays well under the file-length limit.
struct SettingsPruningSectionView: View {
    /// Shared store whose pruning policy these controls read and mutate.
    @ObservedObject var store: KkachiStore

    /// Source of truth for the highlighted segment. User taps update it synchronously so the segmented
    /// control reacts instantly and never reads a value that matches no tag; the persisted write is
    /// allowed to land a runloop later without affecting which segment looks selected.
    @State private var selectedMode: ThresholdMode

    /// In-progress custom delay as a human-scale amount plus unit; seeded from the persisted threshold
    /// and edited live while the custom segment is active.
    @State private var customDraft: CustomThresholdDraft

    /// Seeds editing state from the persisted threshold so reopening Settings restores the user's choice.
    init(store: KkachiStore) {
        self.store = store
        let threshold = store.preferences.policy.inactivityThreshold
        let matchedPreset = ThresholdPreset.availablePresets.first { $0.duration == threshold }
        _selectedMode = State(initialValue: matchedPreset.map { ThresholdMode.preset($0.duration) } ?? .custom)
        _customDraft = State(initialValue: CustomThresholdDraft(duration: threshold))
    }

    /// Lays out the threshold control, the conditional custom field, and the pause/login toggles.
    var body: some View {
        Section("settings.pruning.section") {
            thresholdPicker
            if selectedMode == .custom {
                CustomThresholdField(
                    draft: $customDraft,
                    language: store.preferences.appLanguage
                )
                    .onChange(of: customDraft, perform: persistCustomDraft)
            }
            SettingsPollingIntervalField(store: store)
            Toggle("settings.pause.toggle", isOn: pausedBinding)
                .accessibilityIdentifier("settings.pause")
            Toggle("settings.notifications.toggle", isOn: notifyOnPruneBinding)
                .accessibilityIdentifier("settings.notifications")
            Toggle("settings.launchAtLogin.toggle", isOn: launchAtLoginBinding)
                .accessibilityIdentifier("settings.launchAtLogin")
            if let loginItemErrorKey = store.loginItemErrorKey {
                Text(LocalizedStringKey(loginItemErrorKey))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// Presents quick presets plus a "직접 설정" segment that reveals the custom field.
    private var thresholdPicker: some View {
        Picker("settings.threshold.title", selection: modeBinding) {
            ForEach(ThresholdPreset.availablePresets) { preset in
                Text(LocalizedStringKey(preset.localizationKey))
                    .tag(ThresholdMode.preset(preset.duration))
                    .accessibilityIdentifier("settings.threshold.\(thresholdIdentifier(for: preset))")
            }
            Text("settings.threshold.custom")
                .tag(ThresholdMode.custom)
                .accessibilityIdentifier("settings.threshold.custom")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("settings.threshold")
    }

    /// Highlights the active segment from local state and routes a tap to a preset or to custom mode,
    /// re-seeding the custom field from the live threshold so entering custom never reverts the value.
    private var modeBinding: Binding<ThresholdMode> {
        Binding(
            get: { selectedMode },
            set: { newMode in
                selectedMode = newMode
                switch newMode {
                case .preset(let duration):
                    applyThreshold(duration)
                case .custom:
                    customDraft = CustomThresholdDraft(duration: store.preferences.policy.inactivityThreshold)
                    persistCustomDraft(customDraft)
                }
            }
        )
    }

    /// Persists an edited custom value after the draft applies its unit-aware bounds.
    private func persistCustomDraft(_ draft: CustomThresholdDraft) {
        applyThreshold(draft.duration)
    }

    /// Binds pause state to persisted policy and tracker behavior.
    private var pausedBinding: Binding<Bool> {
        Binding(get: { store.preferences.policy.isPaused }, set: { store.setPaused($0) })
    }

    /// Binds the close-notification preference so users can silence the "Closed N tabs" alert.
    private var notifyOnPruneBinding: Binding<Bool> {
        Binding(get: { store.preferences.policy.notifyOnPrune }, set: { store.setNotifyOnPrune($0) })
    }

    /// Binds launch-at-login toggle to the actual Service Management state.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { store.isLaunchAtLoginEnabled }, set: { store.setLaunchAtLoginEnabled($0) })
    }

    /// Persists a threshold one runloop later so a segmented-picker selection write never feeds back into
    /// the in-flight SwiftUI update; the highlight already tracks `selectedMode`, so the user sees no lag.
    private func applyThreshold(_ threshold: TimeInterval) {
        Task { @MainActor in
            await Task.yield()
            guard store.preferences.policy.inactivityThreshold != threshold else { return }
            store.setThreshold(threshold)
        }
    }

    /// Provides stable automation identifiers for threshold segments.
    private func thresholdIdentifier(for preset: ThresholdPreset) -> String {
        switch preset {
        case .testing: return "testing"
        case .fifteenMinutes: return "fifteen"
        case .thirtyMinutes: return "thirty"
        case .oneHour: return "hour"
        case .oneDay: return "day"
        }
    }
}

/// Identifies which threshold control is active: a fixed preset duration or the custom minute field.
private enum ThresholdMode: Hashable {
    /// A quick preset, identified by its exact duration so the segmented control can match it.
    case preset(TimeInterval)

    /// The user-dialed arbitrary delay shown in the custom field.
    case custom
}
