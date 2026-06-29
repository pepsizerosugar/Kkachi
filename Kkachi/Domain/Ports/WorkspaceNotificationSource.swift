import Foundation

/// Carries workspace lifecycle notifications without exposing AppKit types to domain tracking.
struct WorkspaceNotificationSource {
    let center: NotificationCenter
    let didLaunchApplication: Notification.Name
    let didTerminateApplication: Notification.Name
    let willSleep: Notification.Name
    let didWake: Notification.Name
    let screensDidSleep: Notification.Name
    let screensDidWake: Notification.Name
    let applicationBundleID: (Notification) -> String?

    static func testing(center: NotificationCenter = NotificationCenter()) -> WorkspaceNotificationSource {
        WorkspaceNotificationSource(
            center: center,
            didLaunchApplication: Notification.Name("kkachi.test.didLaunchApplication"),
            didTerminateApplication: Notification.Name("kkachi.test.didTerminateApplication"),
            willSleep: Notification.Name("kkachi.test.willSleep"),
            didWake: Notification.Name("kkachi.test.didWake"),
            screensDidSleep: Notification.Name("kkachi.test.screensDidSleep"),
            screensDidWake: Notification.Name("kkachi.test.screensDidWake"),
            applicationBundleID: { $0.userInfo?["bundleIdentifier"] as? String }
        )
    }
}
