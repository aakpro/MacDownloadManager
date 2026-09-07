import XCTest
@testable import MacDownloaderCore

final class PersistenceManagerTests: XCTestCase {

    func testQueueAndPreferencesPersistence() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("persist_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = PersistenceManager(customStorageDirectory: tempDir)

        let item1 = DownloadItem(
            url: URL(string: "https://example.com/file1.zip")!,
            destinationFolder: tempDir,
            status: .downloading, // Should be reset to paused on load
            totalBytes: 5000,
            downloadedBytes: 2500
        )
        let item2 = DownloadItem(
            url: URL(string: "https://example.com/file2.zip")!,
            destinationFolder: tempDir,
            status: .completed,
            totalBytes: 1000,
            downloadedBytes: 1000
        )

        try manager.saveQueue(items: [item1, item2])

        let loaded = manager.loadQueue()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].url.absoluteString, "https://example.com/file1.zip")
        // Active status was cleanly reset to paused to avoid phantom active downloads
        XCTAssertEqual(loaded[0].status, .paused)
        XCTAssertEqual(loaded[1].status, .completed)

        // Preferences
        let prefs = AppPreferences(
            maxConcurrentDownloads: 5,
            speedLimitBytesPerSec: 1024 * 1024,
            isAutoCategorizationEnabled: false
        )
        try manager.savePreferences(prefs)

        let loadedPrefs = manager.loadPreferences()
        XCTAssertEqual(loadedPrefs.maxConcurrentDownloads, 5)
        XCTAssertEqual(loadedPrefs.speedLimitBytesPerSec, 1024 * 1024)
        XCTAssertEqual(loadedPrefs.isAutoCategorizationEnabled, false)
    }
}
