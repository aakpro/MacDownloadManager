import XCTest
@testable import MacDownloaderCore

final class CategoryManagerTests: XCTestCase {

    func testDestinationSubfolders() {
        let base = URL(fileURLWithPath: "/Users/test/Downloads")
        let manager = CategoryManager(defaultBaseFolder: base, isAutoCategorizationEnabled: true)

        let docFolder = manager.destinationFolder(for: .documents)
        XCTAssertEqual(docFolder.path, "/Users/test/Downloads/Documents")

        let videoFolder = manager.destinationFolder(for: .video)
        XCTAssertEqual(videoFolder.path, "/Users/test/Downloads/Video")

        let archiveFolder = manager.destinationFolder(for: .archives)
        XCTAssertEqual(archiveFolder.path, "/Users/test/Downloads/Archives")
    }

    func testDisabledAutoCategorization() {
        let base = URL(fileURLWithPath: "/Users/test/Downloads")
        let manager = CategoryManager(defaultBaseFolder: base, isAutoCategorizationEnabled: false)

        let docFolder = manager.destinationFolder(for: .documents)
        XCTAssertEqual(docFolder.path, "/Users/test/Downloads")
    }

    func testUniqueFilenameCollisionResolution() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("collision_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let original = "archive.zip"
        // Initially file does not exist -> returns "archive.zip"
        let first = CategoryManager.resolveUniqueFilename(in: tempDir, originalFilename: original)
        XCTAssertEqual(first, "archive.zip")

        // Create the file
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("archive.zip").path, contents: Data())

        // Next resolution should yield "archive (1).zip"
        let second = CategoryManager.resolveUniqueFilename(in: tempDir, originalFilename: original)
        XCTAssertEqual(second, "archive (1).zip")

        // Create that file too
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("archive (1).zip").path, contents: Data())

        // Third should yield "archive (2).zip"
        let third = CategoryManager.resolveUniqueFilename(in: tempDir, originalFilename: original)
        XCTAssertEqual(third, "archive (2).zip")
    }

    func testUniqueFilenameWithQueuedNames() {
        let tempDir = URL(fileURLWithPath: "/tmp/fake_dir")
        let original = "video.mp4"
        let existing: Set<String> = ["video.mp4", "video (1).mp4"]

        let resolved = CategoryManager.resolveUniqueFilename(
            in: tempDir,
            originalFilename: original,
            existingNames: existing
        )
        XCTAssertEqual(resolved, "video (2).mp4")
    }
}
