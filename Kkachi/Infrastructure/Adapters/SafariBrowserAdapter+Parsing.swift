import Foundation

/// Keeps Safari ambiguity checks separate from scripting actions.
@MainActor
extension SafariBrowserAdapter {
    /// Marks duplicated URL/title fingerprints as unsafe for index-based closing.
    func markAmbiguousIdentities(_ tabs: [BrowserTabSnapshot]) -> [BrowserTabSnapshot] {
        let groupedTabs = Dictionary(grouping: tabs, by: { $0.identity.fingerprint })
        let duplicateFingerprints = Set(groupedTabs.filter { $0.value.count > 1 }.keys)
        return tabs.map { tab in
            tab.withIdentityAmbiguity(duplicateFingerprints.contains(tab.identity.fingerprint))
        }
    }
}
