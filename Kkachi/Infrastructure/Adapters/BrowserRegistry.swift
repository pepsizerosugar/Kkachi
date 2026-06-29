import Foundation

/// Provides supported browser metadata and adapter construction.
final class BrowserRegistry {
    /// Stores every browser Kkachi can automate in first-release builds.
    let descriptors: [BrowserDescriptor]

    /// Creates a registry with an injectable descriptor list for tests.
    init(descriptors: [BrowserDescriptor] = SupportedBrowsers.descriptors) {
        self.descriptors = descriptors
    }

    /// Lists browser IDs enabled by default on first launch.
    static var supportedBrowserIDs: Set<BrowserID> {
        SupportedBrowsers.ids
    }

    /// Creates one adapter per descriptor with a shared script runner.
    @MainActor
    func makeAdapters(scriptBridge: AppleScriptBridge = AppleScriptBridge()) -> [any BrowserAdapter] {
        descriptors.map { descriptor in
            switch descriptor.family {
            case .chromium:
                return ChromiumBrowserAdapter(descriptor: descriptor, scriptBridge: scriptBridge)
            case .safari:
                return SafariBrowserAdapter(descriptor: descriptor, scriptBridge: scriptBridge)
            }
        }
    }

    /// Returns the descriptor matching a browser ID, if supported.
    func descriptor(for browserID: BrowserID) -> BrowserDescriptor? {
        descriptors.first { $0.id == browserID }
    }

    /// Defines all supported browser descriptors in display order.
    static let supportedDescriptors: [BrowserDescriptor] = SupportedBrowsers.descriptors
}
