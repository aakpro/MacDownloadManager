import XCTest
@testable import MacDownloaderCore

final class DownloadItemTests: XCTestCase {

    func testFilenameExtraction() {
        let url = URL(string: "https://example.com/downloads/setup_v1.0.dmg?token=xyz123")!
        let filename = DownloadItem.extractFilename(from: url)
        XCTAssertEqual(filename, "setup_v1.0.dmg")
    }

    func testFilenameExtractionFromQueryParameters() {
        let url1 = URL(string: "https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=001-Introduction-07tg-git.ir.mp4")!
        XCTAssertEqual(DownloadItem.extractFilename(from: url1), "001-Introduction-07tg-git.ir.mp4")

        let url2 = URL(string: "https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=002-Understanding%20the%20Roles%20and%20Responsibilities-jtiX-git.ir.srt")!
        XCTAssertEqual(DownloadItem.extractFilename(from: url2), "002-Understanding the Roles and Responsibilities-jtiX-git.ir.srt")

        let s3URL = URL(string: "https://s3.amazonaws.com/bucket/doc?response-content-disposition=attachment%3B%20filename%3D%22guide.pdf%22")!
        XCTAssertEqual(DownloadItem.extractFilename(from: s3URL), "guide.pdf")
    }

    func testCategoryAutoDetection() {
        XCTAssertEqual(DownloadCategory.detect(from: "report.pdf"), .documents)
        XCTAssertEqual(DownloadCategory.detect(from: "archive.tar.gz"), .archives)
        XCTAssertEqual(DownloadCategory.detect(from: "backup.7z"), .archives)
        XCTAssertEqual(DownloadCategory.detect(from: "video.mkv"), .video)
        XCTAssertEqual(DownloadCategory.detect(from: "music.flac"), .audio)
        XCTAssertEqual(DownloadCategory.detect(from: "installer.pkg"), .programs)
        XCTAssertEqual(DownloadCategory.detect(from: "random_data.bin"), .programs)
        XCTAssertEqual(DownloadCategory.detect(from: "unknown.xyz123"), .general)
    }

    func testFormattingHelpers() {
        let dest = URL(fileURLWithPath: "/tmp")
        let item = DownloadItem(
            url: URL(string: "https://example.com/movie.mp4")!,
            destinationFolder: dest,
            status: .downloading,
            totalBytes: 100_000_000,
            downloadedBytes: 50_000_000,
            speed: 5_000_000, // 5 MB/s
            eta: 10 // 10 seconds
        )

        XCTAssertEqual(item.progressRatio, 0.5, accuracy: 0.001)
        XCTAssertEqual(item.formattedProgress, "50.0%")
        XCTAssertEqual(item.formattedETA, "10s")
        XCTAssertTrue(item.formattedSpeed.contains("/s"))
        XCTAssertEqual(item.status.isActive, true)
        XCTAssertEqual(item.status.canPause, true)
    }

    func testStatusTransitions() {
        XCTAssertTrue(DownloadStatus.downloading.isActive)
        XCTAssertTrue(DownloadStatus.connecting.isActive)
        XCTAssertFalse(DownloadStatus.queued.isActive)
        XCTAssertFalse(DownloadStatus.paused.isActive)
        XCTAssertTrue(DownloadStatus.completed.isTerminal)
        XCTAssertTrue(DownloadStatus.failed.isTerminal)
        XCTAssertTrue(DownloadStatus.cancelled.isTerminal)
        XCTAssertFalse(DownloadStatus.downloading.isTerminal)
    }
}
