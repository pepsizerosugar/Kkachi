import XCTest
@testable import Kkachi

/// Verifies the durable restore-history store: round-trip, cap, corruption quarantine,
/// owner-only permissions, and that the tracker reloads persisted history on launch.
@MainActor
final class RestoreHistoryStoreTests: XCTestCase {
    /// Holds the throwaway directory used by one test so real app data is never touched.
    private var directory: URL!

    /// Creates a unique empty directory before each test.
    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RestoreHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// Removes the throwaway directory after each test.
    override func tearDown() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        super.tearDown()
    }

    /// Ensures saved history reloads with its fields intact and original order preserved.
    func testSaveThenLoadRoundTrips() {
        let store = RestoreHistoryStore(directory: directory)
        let first = PrunedTab.sampleHistory(url: "https://a.example")
        let second = PrunedTab.sampleHistory(url: "https://b.example")
        store.save([first, second])

        let loaded = RestoreHistoryStore(directory: directory).load()

        XCTAssertEqual(loaded.map(\.url), [first.url, second.url])
        XCTAssertEqual(loaded.map(\.id), [first.id, second.id])
        XCTAssertEqual(loaded.first?.browserID, first.browserID)
        XCTAssertNil(loaded.first?.originalIdentity, "originalIdentity is intentionally not persisted")
    }

    /// Ensures a missing file is treated as an empty, valid history.
    func testMissingFileLoadsEmpty() {
        XCTAssertTrue(RestoreHistoryStore(directory: directory).load().isEmpty)
    }

    /// Ensures the persisted history never exceeds the newest-thirty cap.
    func testSaveEnforcesHistoryCap() {
        let store = RestoreHistoryStore(directory: directory)
        let tabs = (0..<35).map { PrunedTab.sampleHistory(url: "https://example.com/\($0)") }
        store.save(tabs)

        let loaded = RestoreHistoryStore(directory: directory).load()

        XCTAssertEqual(loaded.count, RestoreHistoryStore.historyLimit)
        XCTAssertEqual(loaded.first?.url, tabs.first?.url)
    }

    /// Ensures a corrupt file is quarantined and the app starts empty without crashing.
    func testCorruptFileIsQuarantined() throws {
        let store = RestoreHistoryStore(directory: directory)
        store.save([.sampleHistory(url: "https://a.example")])
        try Data("not json".utf8).write(to: directory.appendingPathComponent("restore-history.json"))

        let loaded = RestoreHistoryStore(directory: directory).load()

        XCTAssertTrue(loaded.isEmpty)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("restore-history.corrupt.json").path)
        )
    }

    /// Ensures the history file is owner-only so other accounts cannot read closed-tab URLs.
    func testHistoryFileIsOwnerOnly() throws {
        RestoreHistoryStore(directory: directory).save([.sampleHistory(url: "https://a.example")])

        let attributes = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent("restore-history.json").path
        )
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.int16Value, 0o600)
    }

    /// Ensures the on-disk envelope records the schema version for future migration.
    func testSchemaVersionIsPersisted() throws {
        RestoreHistoryStore(directory: directory).save([.sampleHistory(url: "https://a.example")])

        let data = try Data(contentsOf: directory.appendingPathComponent("restore-history.json"))
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"schemaVersion\":\(RestoreHistoryStore.schemaVersion)"))
    }

    /// Ensures the tracker loads persisted history on init and clears it durably.
    func testTrackerLoadsPersistedHistoryAndClearsDurably() {
        RestoreHistoryStore(directory: directory).save([.sampleHistory(url: "https://a.example")])
        let tracker = TabTracker(
            adapters: [FakeBrowserAdapter(tabs: [])],
            preferences: PreferencesStore(defaults: TestDefaults.make()),
            historyStore: RestoreHistoryStore(directory: directory),
            workspaceNotifications: .testing()
        )

        XCTAssertEqual(tracker.prunedTabs.count, 1)

        tracker.clearHistory()

        XCTAssertTrue(tracker.prunedTabs.isEmpty)
        XCTAssertTrue(RestoreHistoryStore(directory: directory).load().isEmpty)
    }
}
