import Foundation

/// Exposes user-initiated commands that operate on the latest live tab rows.
@MainActor
extension TabTracker {
    /// Brings the live browser tab forward for last-second user review.
    func reveal(_ tab: TrackedTab) {
        let snapshot = makeSnapshot(from: tab)
        do {
            guard let adapter = adapterByID[tab.browserID] else {
                throw BrowserAutomationError.executionFailed(operation: "revealTab", details: "unsupportedBrowser")
            }
            _ = try adapter.reveal(snapshot)
        } catch {
            rememberAutomationError(error)
        }
    }

    /// Reconstructs a browser snapshot from UI state without inventing new identity data.
    private func makeSnapshot(from tab: TrackedTab) -> BrowserTabSnapshot {
        BrowserTabSnapshot(
            identity: tab.identity,
            url: tab.url,
            title: tab.title,
            isActive: tab.isActive,
            browserNameKey: tab.browserNameKey,
            isIdentityAmbiguous: tab.isIdentityAmbiguous
        )
    }
}
