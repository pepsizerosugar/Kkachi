import AppKit
import Foundation

/// Writes copied restore URLs to the macOS general pasteboard.
struct SystemPasteboardWriter: PasteboardWriting {
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
