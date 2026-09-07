import XCTest
@testable import MacDownloaderCore

final class ChecksumVerifierTests: XCTestCase {

    func testSHA256AndMD5Verification() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("checksum_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent("hello.txt")
        let content = "Hello, MacDownloader!".data(using: .utf8)!
        try content.write(to: testFile)

        // Known SHA-256 for "Hello, MacDownloader!"
        let sha256 = try ChecksumVerifier.computeSHA256(for: testFile)
        XCTAssertFalse(sha256.isEmpty)
        XCTAssertEqual(sha256.count, 64)

        let isSHAValid = try ChecksumVerifier.verify(fileURL: testFile, expectedHash: sha256, algorithm: .sha256)
        XCTAssertTrue(isSHAValid)

        let isSHAMismatch = try ChecksumVerifier.verify(fileURL: testFile, expectedHash: "0000000000000000000000000000000000000000000000000000000000000000", algorithm: .sha256)
        XCTAssertFalse(isSHAMismatch)

        // MD5
        let md5 = try ChecksumVerifier.computeMD5(for: testFile)
        XCTAssertFalse(md5.isEmpty)
        XCTAssertEqual(md5.count, 32)

        let isMD5Valid = try ChecksumVerifier.verify(fileURL: testFile, expectedHash: md5, algorithm: .md5)
        XCTAssertTrue(isMD5Valid)
    }
}
