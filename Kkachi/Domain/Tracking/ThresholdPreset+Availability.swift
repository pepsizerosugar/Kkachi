import Foundation

/// Keeps release defaults conservative while preserving fast debug validation.
extension ThresholdPreset {
    /// Lists presets that should be visible in Settings for the active build.
    static var availablePresets: [ThresholdPreset] {
        #if DEBUG
        return [.testing, .fifteenMinutes, .thirtyMinutes, .oneHour]
        #else
        return [.fifteenMinutes, .thirtyMinutes, .oneHour]
        #endif
    }
}
