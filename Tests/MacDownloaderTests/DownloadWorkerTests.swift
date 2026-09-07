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
}
