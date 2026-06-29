import Foundation

/// Defines browser metadata that domain defaults and infrastructure adapters both share.
enum SupportedBrowsers {
    static var ids: Set<BrowserID> {
        Set(descriptors.map(\.id))
    }

    static let descriptors: [BrowserDescriptor] = [
        BrowserDescriptor(id: "chrome", bundleIdentifier: "com.google.Chrome", appleScriptName: "Google Chrome", displayNameKey: "browser.chrome", applicationPath: "/Applications/Google Chrome.app", family: .chromium, capabilities: .chromium),
        BrowserDescriptor(id: "safari", bundleIdentifier: "com.apple.Safari", appleScriptName: "Safari", displayNameKey: "browser.safari", applicationPath: "/Applications/Safari.app", family: .safari, capabilities: .safari),
        BrowserDescriptor(id: "edge", bundleIdentifier: "com.microsoft.edgemac", appleScriptName: "Microsoft Edge", displayNameKey: "browser.edge", applicationPath: "/Applications/Microsoft Edge.app", family: .chromium, capabilities: .chromium),
        BrowserDescriptor(id: "whale", bundleIdentifier: "com.naver.Whale", appleScriptName: "Whale", displayNameKey: "browser.whale", applicationPath: "/Applications/Whale.app", family: .chromium, capabilities: .chromium),
        BrowserDescriptor(id: "brave", bundleIdentifier: "com.brave.Browser", appleScriptName: "Brave Browser", displayNameKey: "browser.brave", applicationPath: "/Applications/Brave Browser.app", family: .chromium, capabilities: .chromium),
        BrowserDescriptor(id: "vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi", appleScriptName: "Vivaldi", displayNameKey: "browser.vivaldi", applicationPath: "/Applications/Vivaldi.app", family: .chromium, capabilities: .chromium),
        BrowserDescriptor(id: "opera", bundleIdentifier: "com.operasoftware.Opera", appleScriptName: "Opera", displayNameKey: "browser.opera", applicationPath: "/Applications/Opera.app", family: .chromium, capabilities: .chromium),
        BrowserDescriptor(id: "arc", bundleIdentifier: "company.thebrowser.Browser", appleScriptName: "Arc", displayNameKey: "browser.arc", applicationPath: "/Applications/Arc.app", family: .chromium, capabilities: .chromium)
    ]
}

extension BrowserCapabilities {
    static let chromium = BrowserCapabilities(hasStableTabIDs: true, verifiesIdentityBeforeClose: false)

    static let safari = BrowserCapabilities(hasStableTabIDs: false, verifiesIdentityBeforeClose: true)
}
