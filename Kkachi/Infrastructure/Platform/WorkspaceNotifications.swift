import AppKit
import Foundation

/// Adapts AppKit workspace events into the domain-owned notification source.
enum SystemWorkspaceNotifications {
    static var source: WorkspaceNotificationSource {
        WorkspaceNotificationSource(
            center: NSWorkspace.shared.notificationCenter,
            didLaunchApplication: NSWorkspace.didLaunchApplicationNotification,
            didTerminateApplication: NSWorkspace.didTerminateApplicationNotification,
            willSleep: NSWorkspace.willSleepNotification,
            didWake: NSWorkspace.didWakeNotification,
            screensDidSleep: NSWorkspace.screensDidSleepNotification,
            screensDidWake: NSWorkspace.screensDidWakeNotification,
            applicationBundleID: { notification in
                let runningApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                return runningApplication?.bundleIdentifier
            }
        )
    }
}
