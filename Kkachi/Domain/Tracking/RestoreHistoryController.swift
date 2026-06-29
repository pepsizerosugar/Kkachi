import Foundation

/// Centralizes restore-history list mutations so TabTracker only coordinates side effects.
enum RestoreHistoryController {
    static func append(
        _ tab: BrowserTabSnapshot,
        prunedAt: Date,
        activeBatchID: inout UUID?,
        prunedTabs: inout [PrunedTab],
        historyLimit: Int
    ) {
        let batchID = activeBatchID ?? UUID()
        activeBatchID = batchID
        prunedTabs.insert(
            PrunedTab(id: UUID(), url: tab.url, title: tab.title, prunedAt: prunedAt, batchID: batchID, browserID: tab.identity.browserID, browserNameKey: tab.browserNameKey, originalIdentity: tab.identity),
            at: 0
        )
        if prunedTabs.count > historyLimit {
            prunedTabs.removeLast(prunedTabs.count - historyLimit)
        }
    }

    static func recentBatch(in prunedTabs: [PrunedTab]) -> [PrunedTab] {
        guard let leadBatchID = prunedTabs.first?.batchID else { return [] }
        return prunedTabs.filter { $0.batchID == leadBatchID }
    }

    static func batch(idString: String, in prunedTabs: [PrunedTab]) -> [PrunedTab] {
        prunedTabs.filter { $0.batchID.uuidString == idString }
    }

    static func failureReason(for tab: PrunedTab, browserStatuses: [BrowserStatus]) -> RestoreFailureReason {
        guard let browserStatus = browserStatuses.first(where: { $0.id == tab.browserID }) else {
            return .browserUnavailable
        }
        if !browserStatus.isInstalled { return .browserUnavailable }
        if !browserStatus.isRunning { return .browserNotRunning }
        return .couldNotReopen
    }
}
