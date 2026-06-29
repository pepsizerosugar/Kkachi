@testable import Kkachi

/// Builds compact browser descriptor fixtures for unit tests.
extension BrowserDescriptor {
    /// Provides a stable Chromium-family descriptor for tests.
    static let testChrome = BrowserRegistry.supportedDescriptors[0]

    /// Provides a stable Whale descriptor for multi-browser tests.
    static let testWhale = BrowserRegistry.supportedDescriptors[3]
}
