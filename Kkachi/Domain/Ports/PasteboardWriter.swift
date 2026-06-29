import Foundation

/// Writes text to the user pasteboard through an injectable platform adapter.
protocol PasteboardWriting {
    func copy(_ string: String)
}
