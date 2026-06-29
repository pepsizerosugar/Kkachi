import AppKit
import Foundation

/// Shares platform probes that every browser adapter must perform consistently.
@MainActor
enum BrowserAdapterSupport {
    /// Reports whether the browser bundle exists locally and records the probe result.
    static func isInstalled(_ descriptor: BrowserDescriptor) -> Bool {
        let isInstalled = FileManager.default.fileExists(atPath: descriptor.applicationPath)
        KkachiDebugLog.browser("adapter installed browser=\(descriptor.id.rawValue) installed=\(isInstalled) path=\(descriptor.applicationPath)")
        return isInstalled
    }

    /// Reports whether the browser process is running and records the probe result.
    static func isRunning(_ descriptor: BrowserDescriptor) -> Bool {
        let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: descriptor.bundleIdentifier).isEmpty
        KkachiDebugLog.browser("adapter running browser=\(descriptor.id.rawValue) running=\(isRunning) bundle=\(descriptor.bundleIdentifier)")
        return isRunning
    }

    /// Probes Apple Events with shared operation naming so permission diagnostics remain comparable.
    static func probeAutomation(descriptor: BrowserDescriptor, scriptingBridge: BrowserScriptingBridge) throws {
        let operation = "probeAutomation:\(descriptor.id.rawValue)"
        KkachiDebugLog.browser("adapter probe start browser=\(descriptor.id.rawValue)")
        try scriptingBridge.probeAutomation(operation: operation)
        KkachiDebugLog.browser("adapter probe success browser=\(descriptor.id.rawValue)")
    }
}
