import XCTest
@testable import MacDownloaderCore

@MainActor
final class QueueSchedulerTests: XCTestCase {

    func testAddAndPauseOperations() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("scheduler_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = QueueScheduler(persistenceManager: persistence)
        scheduler.isAutoProcessingEnabled = false

        let urls = [
            URL(string: "https://example.com/item1.zip")!,
            URL(string: "https://example.com/item2.zip")!,
            URL(string: "https://example.com/item3.zip")!
        ]

        scheduler.add(urls: urls, destinationFolder: tempDir, startImmediately: false)
        XCTAssertEqual(scheduler.items.count, 3)
        XCTAssertEqual(scheduler.items[0].status, .queued)
        XCTAssertEqual(scheduler.items[1].status, .queued)
        XCTAssertEqual(scheduler.items[2].status, .queued)

        let firstID = scheduler.items[0].id
        scheduler.pause(id: firstID)
        XCTAssertEqual(scheduler.items[0].status, .paused)

        scheduler.resume(id: firstID)
        XCTAssertEqual(scheduler.items[0].status, .queued)

        // Pause All
        scheduler.pauseAll()
        for item in scheduler.items {
            XCTAssertEqual(item.status, .paused)
        }

        // Resume All
        scheduler.resumeAll()
        for item in scheduler.items {
            XCTAssertEqual(item.status, .queued)
        }

        // Remove
        scheduler.remove(id: firstID)
        XCTAssertEqual(scheduler.items.count, 2)
    }

    func testClearCompleted() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clear_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = QueueScheduler(persistenceManager: persistence)
        scheduler.isAutoProcessingEnabled = false

        let urls = [
            URL(string: "https://example.com/item1.zip")!,
            URL(string: "https://example.com/item2.zip")!
        ]

        scheduler.add(urls: urls, destinationFolder: tempDir, startImmediately: false)
        XCTAssertEqual(scheduler.items.count, 2)

        // Mark item 0 as paused and item 1 as completed
        scheduler.pause(id: scheduler.items[0].id)
        scheduler.updateItemStatus(id: scheduler.items[1].id, status: .completed)

        XCTAssertEqual(scheduler.items[0].status, .paused)
        XCTAssertEqual(scheduler.items[1].status, .completed)

        // Clear completed should remove item 1
        scheduler.clearCompleted()
        XCTAssertEqual(scheduler.items.count, 1)
        XCTAssertEqual(scheduler.items[0].status, .paused)

        // Reload from persistence to ensure state is synchronized
        let reloadedScheduler = QueueScheduler(persistenceManager: persistence)
        reloadedScheduler.isAutoProcessingEnabled = false
        XCTAssertEqual(reloadedScheduler.items.count, 1)
        XCTAssertEqual(reloadedScheduler.items[0].status, .paused)
    }

    func testBatchCollisionAvoidanceInScheduler() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("batch_coll_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = QueueScheduler(persistenceManager: persistence)
        scheduler.isAutoProcessingEnabled = false

        let urls = [
            URL(string: "https://git.ir/api/download?filename=video.mp4&id=1")!,
            URL(string: "https://git.ir/api/download?filename=video.mp4&id=2")!,
            URL(string: "https://git.ir/api/download?filename=video.mp4&id=3")!
        ]

        scheduler.add(urls: urls, destinationFolder: tempDir, startImmediately: false)
        XCTAssertEqual(scheduler.items.count, 3)
        XCTAssertEqual(scheduler.items[0].filename, "video.mp4")
        XCTAssertEqual(scheduler.items[1].filename, "video (1).mp4")
        XCTAssertEqual(scheduler.items[2].filename, "video (2).mp4")
    }

    func testBatchDeletionAndDiskFileCleanup() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("del_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = QueueScheduler(persistenceManager: persistence)
        scheduler.isAutoProcessingEnabled = false

        let urls = [
            URL(string: "https://example.com/file1.zip")!,
            URL(string: "https://example.com/file2.zip")!,
            URL(string: "https://example.com/file3.zip")!
        ]

        scheduler.add(urls: urls, destinationFolder: tempDir, startImmediately: false)
        XCTAssertEqual(scheduler.items.count, 3)

        // Create dummy destination and part files on disk
        let item1 = scheduler.items[0]
        let item2 = scheduler.items[1]
        let dummyData = "dummy content".data(using: .utf8)!
        try dummyData.write(to: item1.destinationFileURL)
        try dummyData.write(to: item1.partFileURL)
        try dummyData.write(to: item2.partFileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: item1.destinationFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item1.partFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item2.partFileURL.path))

        // Batch remove item1 and item2 with deleteFiles: true
        let idsToDelete: Set<UUID> = [item1.id, item2.id]
        scheduler.remove(ids: idsToDelete, deleteFiles: true)

        XCTAssertEqual(scheduler.items.count, 1)
        XCTAssertEqual(scheduler.items[0].filename, "file3.zip")
        XCTAssertFalse(FileManager.default.fileExists(atPath: item1.destinationFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: item1.partFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: item2.partFileURL.path))
    }

    func testClearFailedAndClearAll() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clear_all_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = QueueScheduler(persistenceManager: persistence)
        scheduler.isAutoProcessingEnabled = false

        let urls = [
            URL(string: "https://example.com/itemA.zip")!,
            URL(string: "https://example.com/itemB.zip")!,
            URL(string: "https://example.com/itemC.zip")!
        ]

        scheduler.add(urls: urls, destinationFolder: tempDir, startImmediately: false)
        XCTAssertEqual(scheduler.items.count, 3)

        // Mark itemA as failed, itemB as cancelled, itemC as completed
        scheduler.updateItemStatus(id: scheduler.items[0].id, status: .failed)
        scheduler.updateItemStatus(id: scheduler.items[1].id, status: .cancelled)
        scheduler.updateItemStatus(id: scheduler.items[2].id, status: .completed)

        // Clear failed removes failed & cancelled
        scheduler.clearFailed()
        XCTAssertEqual(scheduler.items.count, 1)
        XCTAssertEqual(scheduler.items[0].status, .completed)

        // Clear all removes everything
        scheduler.clearAll()
        XCTAssertTrue(scheduler.items.isEmpty)
    }

    func testCustomBaseFolderRouting() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("custom_base_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = QueueScheduler(persistenceManager: persistence)
        scheduler.isAutoProcessingEnabled = false

        let url = URL(string: "https://git.ir/api/download?filename=video.mp4")!
        scheduler.add(urls: [url], destinationFolder: tempDir, startImmediately: false)

        XCTAssertEqual(scheduler.items.count, 1)
        // With custom destinationFolder specified, destinationFolder should be tempDir directly, not nested
        XCTAssertEqual(scheduler.items[0].destinationFolder.path, tempDir.path)
    }
}
