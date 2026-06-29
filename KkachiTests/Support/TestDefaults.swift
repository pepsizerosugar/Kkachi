import Foundation

/// Creates isolated defaults containers for tests.
enum TestDefaults {
    /// Returns a unique empty defaults suite for one test.
    static func make() -> UserDefaults {
        let suiteName = "KkachiTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
