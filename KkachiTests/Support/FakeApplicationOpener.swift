import Foundation
@testable import Kkachi

/// Records app and URL open requests so restore-fallback tests avoid Launch Services.
@MainActor
final class FakeApplicationOpener: ApplicationOpening {
    /// Records browser application launch requests.
    var openedApplications: [URL] = []

    /// Records default-browser URL fallbacks.
    var openedURLs: [URL] = []

    /// Captures application launches instead of calling Launch Services.
    func openApplication(at url: URL) {
        openedApplications.append(url)
    }

    /// Captures default-browser fallbacks instead of opening a real URL.
    func openURL(_ url: URL) {
        openedURLs.append(url)
    }
}

/// Captures pasteboard writes without touching the user's real pasteboard.
final class FakePasteboardWriter: PasteboardWriting {
    private(set) var copiedStrings: [String] = []

    func copy(_ string: String) {
        copiedStrings.append(string)
    }
}

/// Keeps restore history in memory for tests that do not exercise file persistence.
final class FakeRestoreHistoryStore: RestoreHistoryStoring {
    var tabs: [PrunedTab]

    init(tabs: [PrunedTab] = []) {
        self.tabs = tabs
    }

    func load() -> [PrunedTab] {
        tabs
    }

    func save(_ tabs: [PrunedTab]) {
        self.tabs = tabs
    }
}
