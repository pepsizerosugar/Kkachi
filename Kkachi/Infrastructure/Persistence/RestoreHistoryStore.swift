import Foundation

/// Persists Kkachi's restore history to a durable, local, atomically written file so
/// tucked-away tabs survive quit, crash, and reboot. This is the core trust guarantee:
/// without it the history is in-memory only and is lost the moment the app restarts.
///
/// Privacy posture (intentionally honest): the file holds only the minimal restorable
/// fields {url, title, browser, prune-time}, is written owner-only (`0600`), is excluded
/// from Time Machine/iCloud backup, and its directory is marked to be skipped by Spotlight.
/// It is NOT encrypted at rest in v1 — that protects against casual disk/backup inspection,
/// not a determined local attacker, and is stated plainly in PRIVACY/SECURITY.
final class RestoreHistoryStore: RestoreHistoryStoring {
    /// Identifies the on-disk shape so future format changes can migrate older files.
    static let schemaVersion = 1

    /// Mirrors `TabTracker.historyLimit` so the file never grows past the newest 30.
    static let historyLimit = 30

    /// Points at the JSON file that holds the persisted history.
    private let fileURL: URL

    /// Points at the Kkachi container directory inside Application Support.
    private let directoryURL: URL

    /// Wraps persisted tabs with a version and save time so loads can migrate safely.
    private struct Envelope: Codable {
        let schemaVersion: Int
        let savedAt: Date
        let tabs: [PrunedTab]
    }

    /// Resolves the storage location; tests inject a temporary directory for isolation.
    init(directory: URL? = nil) {
        let base = directory ?? Self.defaultDirectory()
        self.directoryURL = base
        self.fileURL = base.appendingPathComponent("restore-history.json", isDirectory: false)
    }

    /// Returns ~/Library/Application Support/Kkachi for production, but a unique throwaway
    /// directory under XCTest so a test can never read or write the user's real history.
    /// Mirrors `AppDelegate.isRunningUnderTests`.
    private static func defaultDirectory() -> URL {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("KkachiHistoryTests-\(UUID().uuidString)", isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Kkachi", isDirectory: true)
    }

    /// Loads persisted history newest-first. A missing file yields empty; a corrupt file is
    /// quarantined (renamed aside) and treated as empty so a bad file never crashes launch.
    func load() -> [PrunedTab] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let envelope = try Self.makeDecoder().decode(Envelope.self, from: data)
            return Array(migrate(envelope).prefix(Self.historyLimit))
        } catch {
            quarantineCorruptFile()
            return []
        }
    }

    /// Persists history atomically with private permissions. Never throws into the caller:
    /// a failed write must not crash the app or interrupt pruning.
    func save(_ tabs: [PrunedTab]) {
        let capped = Array(tabs.prefix(Self.historyLimit))
        let envelope = Envelope(schemaVersion: Self.schemaVersion, savedAt: Date(), tabs: capped)
        do {
            try ensureDirectory()
            let data = try Self.makeEncoder().encode(envelope)
            try data.write(to: fileURL, options: [.atomic])
            applyFilePrivacy()
        } catch {
            KkachiDebugLog.tracking("history persist failed error=\(String(describing: error))")
        }
    }

    /// Applies version-aware migration; v1 is the current shape so tabs pass through.
    private func migrate(_ envelope: Envelope) -> [PrunedTab] {
        // Future schema bumps branch here; v1 needs no transformation.
        envelope.tabs
    }

    /// Creates the container directory and marks it to be skipped by Spotlight indexing.
    private func ensureDirectory() throws {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let marker = directoryURL.appendingPathComponent(".metadata_never_index", isDirectory: false)
        if !FileManager.default.fileExists(atPath: marker.path) {
            try? Data().write(to: marker, options: [.atomic])
        }
    }

    /// Locks the file to owner-only access and excludes it from backups.
    private func applyFilePrivacy() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(values)
    }

    /// Moves a corrupt file aside so the next save starts clean without silently deleting data.
    private func quarantineCorruptFile() {
        let quarantineURL = directoryURL.appendingPathComponent("restore-history.corrupt.json", isDirectory: false)
        try? FileManager.default.removeItem(at: quarantineURL)
        try? FileManager.default.moveItem(at: fileURL, to: quarantineURL)
        KkachiDebugLog.tracking("history file corrupt; quarantined as \(quarantineURL.lastPathComponent)")
    }

    /// Builds a JSON encoder with ISO-8601 dates and sorted keys for a stable on-disk format.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// Builds a JSON decoder matching the encoder's ISO-8601 date strategy.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
