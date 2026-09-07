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
}
