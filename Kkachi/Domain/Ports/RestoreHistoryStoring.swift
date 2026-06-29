import Foundation

/// Provides durable restore-history storage without tying tracking policy to a filesystem format.
protocol RestoreHistoryStoring {
    func load() -> [PrunedTab]

    func save(_ tabs: [PrunedTab])
}
