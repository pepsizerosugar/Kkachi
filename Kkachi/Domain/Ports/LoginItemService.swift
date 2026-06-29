import Foundation

/// Controls whether Kkachi is registered as a macOS login item.
@MainActor
protocol LoginItemServicing {
    /// Reports the current OS-backed login item state.
    var isEnabled: Bool { get }

    /// Applies the requested login item state through Service Management.
    func setEnabled(_ isEnabled: Bool) throws
}
