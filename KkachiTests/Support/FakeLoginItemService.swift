@testable import Kkachi

/// Supplies deterministic login item behavior for store tests.
@MainActor
final class FakeLoginItemService: LoginItemServicing {
    /// Stores the fake OS-backed login item state.
    var isEnabled: Bool

    /// Controls whether the next state change should fail.
    var shouldFail = false

    /// Records requested state changes for assertions.
    var requests: [Bool] = []

    /// Creates a fake login item service with a known initial state.
    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    /// Applies or rejects the requested state change based on test setup.
    func setEnabled(_ isEnabled: Bool) throws {
        requests.append(isEnabled)
        if shouldFail {
            throw BrowserAutomationError.executionFailed(operation: "setLoginItem", details: "failed")
        }
        self.isEnabled = isEnabled
    }
}
