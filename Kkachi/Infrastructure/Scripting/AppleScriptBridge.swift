import Foundation

/// Retains legacy AppleScript literal helpers used by low-level tests.
final class AppleScriptBridge {
    /// Creates a stateless helper value for existing adapter construction APIs.
    init() {}

    /// Executes a compiled AppleScript source and converts script errors into app diagnostics.
    func execute(_ source: String, operation: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            KkachiDebugLog.scripting("appleScript compile failed operation=\(operation)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: "compileFailed")
        }

        var scriptError: NSDictionary?
        let result = script.executeAndReturnError(&scriptError)
        if let scriptError {
            KkachiDebugLog.scripting("appleScript execute failed operation=\(operation) error=\(scriptError)")
            throw BrowserAutomationError.executionFailed(operation: operation, details: String(describing: scriptError))
        }
        return result
    }

    /// Escapes Swift strings so they are safe inside AppleScript string literals.
    static func quotedAppleScriptString(_ value: String) -> String {
        let backslashEscaped = value.replacingOccurrences(of: "\\", with: "\\\\")
        let quoteEscaped = backslashEscaped.replacingOccurrences(of: "\"", with: "\\\"")
        let newlineEscaped = quoteEscaped.replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(newlineEscaped)\""
    }

    /// Emits numeric IDs raw while supporting quoted text IDs from Chromium.
    static func identifierLiteral(_ identifier: String) -> String {
        let nonDigits = CharacterSet.decimalDigits.inverted
        if !identifier.isEmpty, identifier.rangeOfCharacter(from: nonDigits) == nil {
            return identifier
        }
        return quotedAppleScriptString(identifier)
    }
}
