import AppKit
import Foundation

/// Uses the user's workspace to open browser applications in production.
@MainActor
struct WorkspaceApplicationOpener: ApplicationOpening {
    func openApplication(at url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func openURL(_ url: URL) {
        _ = NSWorkspace.shared.open(url)
    }
}
