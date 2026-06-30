import Foundation

/// Defines the quick inactivity-threshold choices exposed in Settings. Split out of TrackingModels so
/// that file stays under the length limit; the `+Availability` extension adds the build-aware preset
/// list on top of this base enum.
enum ThresholdPreset: CaseIterable, Identifiable {
    /// Keeps the short Phase 1 threshold available for development checks.
    case testing

    /// Prunes short distractions without being too aggressive.
    case fifteenMinutes

    /// Provides the recommended balanced default for normal users.
    case thirtyMinutes

    /// Gives long reading sessions more room before pruning.
    case oneHour

    /// Lets users leave intentionally parked tabs alone for a full day.
    case oneDay

    /// Uses duration as stable identity because presets are unique by time.
    var id: TimeInterval { duration }

    /// Returns the threshold duration represented by this preset.
    var duration: TimeInterval {
        switch self {
        case .testing:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        case .oneDay:
            return 24 * 60 * 60
        }
    }

    /// Provides the localization key for Settings segmented controls.
    var localizationKey: String {
        switch self {
        case .testing:
            return "settings.threshold.testing"
        case .fifteenMinutes:
            return "settings.threshold.fifteen"
        case .thirtyMinutes:
            return "settings.threshold.thirty"
        case .oneHour:
            return "settings.threshold.hour"
        case .oneDay:
            return "settings.threshold.day"
        }
    }
}
