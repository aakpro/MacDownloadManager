import XCTest
@testable import MacDownloaderCore

final class DownloadItemTests: XCTestCase {

    func testFilenameExtraction() {
        let url = URL(string: "https://example.com/downloads/setup_v1.0.dmg?token=xyz123")!
        let filename = DownloadItem.extractFilename(from: url)
        XCTAssertEqual(filename, "setup_v1.0.dmg")
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
