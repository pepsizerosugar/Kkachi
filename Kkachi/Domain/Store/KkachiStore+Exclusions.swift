import Foundation

/// Groups batch protected-site (exclusion) commands so the core store stays small and a paste-many add
/// or a Remove All re-evaluates live tabs exactly once instead of once per rule.
@MainActor
extension KkachiStore {
    /// Adds several host-suffix rules from a single paste or typed batch. Each token is validated and
    /// de-duplicated by `preferences.addExclusion`, and the pruning policy is applied only once if any
    /// rule actually landed. Returns how many were newly added versus skipped (invalid or already
    /// protected) so Settings can summarize the batch instead of silently dropping input.
    @discardableResult
    func addExclusions(_ rawValues: [String]) -> (added: Int, skipped: Int) {
        var added = 0
        for rawValue in rawValues where preferences.addExclusion(rawValue) {
            added += 1
        }
        if added > 0 { tracker.applyPolicy(preferences.policy) }
        return (added: added, skipped: rawValues.count - added)
    }

    /// Clears every protected-site rule in one pass and re-evaluates live tabs once. Tabs on those sites
    /// become eligible for pruning again immediately, so the Settings caller guards this behind a
    /// confirmation. No-ops when nothing is protected, avoiding a needless policy re-evaluation.
    func removeAllExclusions() {
        guard !preferences.policy.exclusions.isEmpty else { return }
        preferences.removeAllExclusions()
        tracker.applyPolicy(preferences.policy)
    }
}
