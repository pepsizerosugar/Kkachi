import Foundation
@testable import Kkachi

/// Builds compact test fixtures for pruned tab history.
extension PrunedTab {
    /// Creates a restorable history item for store tests.
    static func sampleHistory(url: String, descriptor: BrowserDescriptor = .testChrome) -> PrunedTab {
        PrunedTab(
            id: UUID(),
            url: URL(string: url)!,
            title: "Example",
            prunedAt: Date(),
            batchID: UUID(),
            browserID: descriptor.id,
            browserNameKey: descriptor.displayNameKey,
            originalIdentity: nil
        )
    }
}
