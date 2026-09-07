import XCTest
@testable import MacDownloaderCore

final class DownloadWorkerTests: XCTestCase {

    func testWorkerInitializationAndPath() async {
        let dest = URL(fileURLWithPath: "/tmp/downloads_test")
        let item = DownloadItem(
            url: URL(string: "https://example.com/test_file.zip")!,
            destinationFolder: dest
        )

        let worker = DownloadWorker(item: item)
        let workerItem = await worker.item

        XCTAssertEqual(workerItem.filename, "test_file.zip")
        XCTAssertEqual(workerItem.destinationFileURL.lastPathComponent, "test_file.zip")
        XCTAssertEqual(workerItem.partFileURL.lastPathComponent, "test_file.zip.part")
        XCTAssertEqual(workerItem.status, .queued)
    }

    func testWorkerPauseAndCancel() async {
        let dest = URL(fileURLWithPath: "/tmp/downloads_test_pause")
        let item = DownloadItem(
            url: URL(string: "https://example.com/test_pause.zip")!,
            destinationFolder: dest,
            status: .downloading
        )

        let worker = DownloadWorker(item: item)
        await worker.pause()

        var updated = await worker.item
        XCTAssertEqual(updated.status, .paused)
        XCTAssertEqual(updated.speed, 0)

        await worker.cancel()
        updated = await worker.item
        XCTAssertEqual(updated.status, .cancelled)
    }

    func testWorkerCancelCleansUpPartFile() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("worker_cancel_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = DownloadItem(
            url: URL(string: "https://example.com/movie.mp4")!,
            destinationFolder: tempDir,
            status: .downloading
        )

        // Write partial file
        try "partial data".data(using: .utf8)!.write(to: item.partFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.partFileURL.path))

        let worker = DownloadWorker(item: item)
        await worker.cancel()

        let updated = await worker.item
        XCTAssertEqual(updated.status, .cancelled)
        // Part file should be deleted on cancel
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.partFileURL.path))
        // Destination file should NOT exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.destinationFileURL.path))
    }

    func testWorkerPausePreservesPartFile() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("worker_pause_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = DownloadItem(
            url: URL(string: "https://example.com/movie.mp4")!,
            destinationFolder: tempDir,
            status: .downloading
        )

        // Write partial file
        try "partial data".data(using: .utf8)!.write(to: item.partFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.partFileURL.path))

        let worker = DownloadWorker(item: item)
        await worker.pause()

        let updated = await worker.item
        XCTAssertEqual(updated.status, .paused)
        // Part file should still be preserved for resuming
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.partFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.destinationFileURL.path))
    }
}
