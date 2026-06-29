import XCTest
@testable import Kkachi

/// Measures the real ScriptingBridge path without mutating or closing browser tabs.
@MainActor
final class KkachiRealBrowserPerformanceTests: XCTestCase {
    /// Requires explicit opt-in because this suite can trigger macOS Automation prompts.
    private let optInEnvironmentKey = "KKACHI_REAL_BROWSER_PERF"

    /// Allows quarantine jobs to narrow the real-browser set by stable browser IDs.
    private let browserIDsEnvironmentKey = "KKACHI_REAL_BROWSER_IDS"

    /// Captures Apple Events probe and fetch cost against currently running browsers.
    func testRunningRealBrowserFetchPerformance() throws {
        try requireExplicitOptIn()
        let adapters = runnableAdapters()
        guard !adapters.isEmpty else {
            throw XCTSkip("No selected supported browsers are installed and running.")
        }

        for adapter in adapters {
            XCTAssertNoThrow(try adapter.probeAutomation(), "Automation probe failed for \(adapter.descriptor.id.rawValue).")
        }

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            var fetchedTabCount = 0
            for adapter in adapters {
                do {
                    fetchedTabCount += try adapter.fetchTabs().count
                } catch {
                    XCTFail("Fetch failed for \(adapter.descriptor.id.rawValue): \(error)")
                }
            }
            XCTAssertGreaterThanOrEqual(fetchedTabCount, 0)
        }
    }

    /// Skips the suite unless a caller intentionally accepts real browser side effects.
    private func requireExplicitOptIn() throws {
        guard ProcessInfo.processInfo.environment[optInEnvironmentKey] == "1" else {
            throw XCTSkip("Set \(optInEnvironmentKey)=1 to run real browser performance tests.")
        }
    }

    /// Builds production adapters for the requested installed and running browsers.
    private func runnableAdapters() -> [any BrowserAdapter] {
        let descriptors = selectedDescriptors()
        let adapters = BrowserRegistry(descriptors: descriptors).makeAdapters()
        return adapters.filter { $0.isInstalled() && $0.isRunning() }
    }

    /// Resolves the optional comma-separated browser ID allowlist.
    private func selectedDescriptors() -> [BrowserDescriptor] {
        let rawIDs = ProcessInfo.processInfo.environment[browserIDsEnvironmentKey] ?? ""
        let selectedIDs = Set(rawIDs.split(separator: ",").map { BrowserID(rawValue: String($0.trimmingCharacters(in: .whitespacesAndNewlines))) })
        guard !selectedIDs.isEmpty else {
            return BrowserRegistry.supportedDescriptors
        }
        return BrowserRegistry.supportedDescriptors.filter { selectedIDs.contains($0.id) }
    }
}
