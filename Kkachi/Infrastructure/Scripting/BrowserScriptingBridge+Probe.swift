import Foundation
import ScriptingBridge

/// Keeps automation readiness checks on the same ScriptingBridge path used for polling.
@MainActor
extension BrowserScriptingBridge {
    /// Verifies that the browser accepts a harmless scriptable windows read.
    func probeAutomation(operation: String) throws {
        let app = try application(operation: operation)
        _ = try elementObjects(app.value(forKey: "windows"), operation: operation)
    }
}
