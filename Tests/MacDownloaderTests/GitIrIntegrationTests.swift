import XCTest
@testable import MacDownloaderCore

final class GitIrIntegrationTests: XCTestCase {

    /// Tests that a real git.ir link downloads completely and successfully with Referer and redirect handling.
    func testLiveGitIrSubtitleDownloadAndDeletion() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gitir_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Use the first SRT link from user's test dataset (small file size, fast download)
        let srtURL = URL(string: "https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=001-Introduction-07tg-git.ir.srt")!

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = await QueueScheduler(persistenceManager: persistence)
        await MainActor.run {
            scheduler.isAutoProcessingEnabled = false
        }

        // Add to queue
        await MainActor.run {
            scheduler.add(urls: [srtURL], destinationFolder: tempDir, startImmediately: false)
        }

        let items = await scheduler.items
        XCTAssertEqual(items.count, 1)
        let item = items[0]
        XCTAssertEqual(item.filename, "001-Introduction-07tg-git.ir.srt")
        XCTAssertEqual(item.destinationFolder.path, tempDir.path)

        // Run worker
        let worker = DownloadWorker(item: item)
        let expectation = expectation(description: "Download completes successfully")

        await worker.setCallbacks(
            onProgress: { _ in },
            onComplete: { completedItem in
                XCTAssertEqual(completedItem.status, .completed)
                XCTAssertTrue(completedItem.downloadedBytes > 0)
                expectation.fulfill()
            },
            onFail: { failedItem, error in
                XCTFail("Download failed with error: \(error.localizedDescription)")
                expectation.fulfill()
            }
        )

        await worker.start()
        await fulfillment(of: [expectation], timeout: 30)

        let completedWorkerItem = await worker.item
        XCTAssertEqual(completedWorkerItem.status, .completed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: completedWorkerItem.destinationFileURL.path))

        // Verify file contents exist and are non-empty
        let downloadedData = try Data(contentsOf: completedWorkerItem.destinationFileURL)
        XCTAssertTrue(downloadedData.count > 0)

        // Now test DELETION with deleteFiles: true
        await MainActor.run {
            scheduler.remove(id: item.id, deleteFiles: true)
        }

        let remainingItems = await scheduler.items
        XCTAssertEqual(remainingItems.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: completedWorkerItem.destinationFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: completedWorkerItem.partFileURL.path))
    }

    /// Tests video download streaming, progress reception, pausing, and disk cleanup.
    func testLiveGitIrVideoProgressAndPauseCancel() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gitir_video_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let videoURL = URL(string: "https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=001-Introduction-07tg-git.ir.mp4")!

        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let scheduler = await QueueScheduler(persistenceManager: persistence)
        await MainActor.run {
            scheduler.isAutoProcessingEnabled = false
            scheduler.add(urls: [videoURL], destinationFolder: tempDir, startImmediately: false)
        }

        let items = await scheduler.items
        XCTAssertEqual(items.count, 1)
        let item = items[0]
        XCTAssertEqual(item.filename, "001-Introduction-07tg-git.ir.mp4")

        let worker = DownloadWorker(item: item)
        let progressExpectation = expectation(description: "Received progress chunks")
        progressExpectation.assertForOverFulfill = false

        await worker.setCallbacks(
            onProgress: { updatedItem in
                if updatedItem.downloadedBytes > 50_000 {
                    progressExpectation.fulfill()
                }
            },
            onComplete: { _ in },
            onFail: { _, error in
                XCTFail("Video download failed: \(error.localizedDescription)")
                progressExpectation.fulfill()
            }
        )

        await worker.start()
        await fulfillment(of: [progressExpectation], timeout: 20)

        // Pause download while downloading
        await worker.pause()
        let pausedItem = await worker.item
        XCTAssertEqual(pausedItem.status, .paused)
        // Part file or segment part files exist and are populated
        let partialFilesExist = FileManager.default.fileExists(atPath: pausedItem.partFileURL.path)
            || pausedItem.segments.contains { FileManager.default.fileExists(atPath: pausedItem.segmentFileURL(for: $0).path) }
        XCTAssertTrue(partialFilesExist)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pausedItem.destinationFileURL.path))

        // Clean up with worker cancel and scheduler removal
        await worker.cancel()
        await MainActor.run {
            scheduler.remove(id: item.id, deleteFiles: true)
        }
        let remainingPartialFilesExist = FileManager.default.fileExists(atPath: pausedItem.partFileURL.path)
            || pausedItem.segments.contains { FileManager.default.fileExists(atPath: pausedItem.segmentFileURL(for: $0).path) }
        XCTAssertFalse(remainingPartialFilesExist)
    }
}
