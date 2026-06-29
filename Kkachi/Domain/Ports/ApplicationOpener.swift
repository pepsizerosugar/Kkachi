import Foundation

/// Opens external applications for setup flows while remaining injectable in tests.
@MainActor
protocol ApplicationOpening {
    /// Opens the application at the resolved Launch Services URL.
    func openApplication(at url: URL)

    /// Opens a URL in the user's default handler; the restore fallback when the origin browser is gone.
    func openURL(_ url: URL)
}
