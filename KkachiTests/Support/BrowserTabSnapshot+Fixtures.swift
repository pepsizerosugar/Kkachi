import Foundation
@testable import Kkachi

/// Builds compact test fixtures for browser tab snapshots.
extension BrowserTabSnapshot {
    /// Creates a valid Chromium-like snapshot for tracker tests.
    static func sample(
        tabID: String = "2",
        isActive: Bool,
        mediaState: BrowserMediaState = .notPlaying,
        descriptor: BrowserDescriptor = .testChrome
    ) -> BrowserTabSnapshot {
        let url = URL(string: "https://example.com")!
        let title = "Example"
        let identity = BrowserTabIdentity(
            browserID: descriptor.id,
            windowID: "1",
            tabID: tabID,
            windowIndex: nil,
            tabIndex: nil,
            fingerprint: BrowserTabFingerprint(url: url, title: title)
        )
        return BrowserTabSnapshot(identity: identity, url: url, title: title, isActive: isActive, mediaState: mediaState, browserNameKey: descriptor.displayNameKey)
    }
}
