import XCTest
import CryptoKit
@testable import MacDownloaderCore

final class MultiSegmentDownloadTests: XCTestCase {

    func testSegmentCalculation_EvenDivision() {
        let segments = DownloadSegment.calculateSegments(
            totalBytes: 1000,
            segmentCount: 4,
            filename: "video.mp4"
        )

        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments[0].startByte, 0)
        XCTAssertEqual(segments[0].endByte, 249)
        XCTAssertEqual(segments[0].totalBytes, 250)

        XCTAssertEqual(segments[1].startByte, 250)
        XCTAssertEqual(segments[1].endByte, 499)
        XCTAssertEqual(segments[1].totalBytes, 250)

        XCTAssertEqual(segments[2].startByte, 500)
        XCTAssertEqual(segments[2].endByte, 749)
        XCTAssertEqual(segments[2].totalBytes, 250)

        XCTAssertEqual(segments[3].startByte, 750)
        XCTAssertEqual(segments[3].endByte, 999)
        XCTAssertEqual(segments[3].totalBytes, 250)

        let totalSegmentBytes = segments.reduce(0) { $0 + $1.totalBytes }
        XCTAssertEqual(totalSegmentBytes, 1000)
    }

    func testSegmentCalculation_UnevenDivision() {
        let segments = DownloadSegment.calculateSegments(
            totalBytes: 1003,
            segmentCount: 4,
            filename: "archive.zip"
        )

        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments[0].startByte, 0)
        XCTAssertEqual(segments[0].endByte, 249)

        XCTAssertEqual(segments[1].startByte, 250)
        XCTAssertEqual(segments[1].endByte, 499)

        XCTAssertEqual(segments[2].startByte, 500)
        XCTAssertEqual(segments[2].endByte, 749)

        XCTAssertEqual(segments[3].startByte, 750)
        XCTAssertEqual(segments[3].endByte, 1002) // Final segment absorbs remainder

        let totalSegmentBytes = segments.reduce(0) { $0 + $1.totalBytes }
        XCTAssertEqual(totalSegmentBytes, 1003)
    }

    func testSegmentCalculation_SmallFile() {
        let segments = DownloadSegment.calculateSegments(
            totalBytes: 3,
            segmentCount: 8,
            filename: "tiny.txt"
        )

        // Cannot have more segments than bytes
        XCTAssertEqual(segments.count, 3)
        let totalSegmentBytes = segments.reduce(0) { $0 + $1.totalBytes }
        XCTAssertEqual(totalSegmentBytes, 3)
    }

    func testSegmentProgressTracking() {
        var seg = DownloadSegment(
            id: 0,
            startByte: 0,
            endByte: 99,
            downloadedBytes: 0,
            isCompleted: false,
            tempFileName: "test.part.seg0"
        )

        XCTAssertEqual(seg.totalBytes, 100)
        XCTAssertEqual(seg.progress, 0.0)
        XCTAssertFalse(seg.isCompleted)

        seg.downloadedBytes = 50
        XCTAssertEqual(seg.progress, 0.5)

        seg.downloadedBytes = 100
        seg.isCompleted = true
        XCTAssertEqual(seg.progress, 1.0)
        XCTAssertTrue(seg.isCompleted)
    }

    func testSegmentFileURL() {
        let tempDir = FileManager.default.temporaryDirectory
        let item = DownloadItem(
            url: URL(string: "https://example.com/bundle.dmg")!,
            destinationFolder: tempDir,
            maxSegments: 4
        )

        let seg = DownloadSegment(
            id: 2,
            startByte: 200,
            endByte: 299,
            tempFileName: "\(item.filename).part.seg2"
        )

        let fileURL = item.segmentFileURL(for: seg)
        XCTAssertEqual(fileURL.lastPathComponent, "\(item.filename).part.seg2")
        XCTAssertEqual(fileURL.deletingLastPathComponent(), tempDir)
    }

    func testMultiSegmentStitching() throws {
        let fileManager = FileManager.default
        let testDir = fileManager.temporaryDirectory.appendingPathComponent("MacDownloaderTest_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: testDir) }

        // Generate known data pattern
        var fullData = Data()
        for i in 0..<100_000 {
            fullData.append(UInt8(i % 256))
        }

        let segments = DownloadSegment.calculateSegments(
            totalBytes: Int64(fullData.count),
            segmentCount: 4,
            filename: "reassembly_test.bin"
        )

        // Write each segment's slice to its temp file
        for seg in segments {
            let segURL = testDir.appendingPathComponent(seg.tempFileName)
            let slice = fullData.subdata(in: Int(seg.startByte)..<Int(seg.endByte + 1))
            try slice.write(to: segURL)
        }

        // Reassemble into destination file
        let assembledURL = testDir.appendingPathComponent("reassembly_test.bin")
        fileManager.createFile(atPath: assembledURL.path, contents: nil)
        let assemblyHandle = try FileHandle(forWritingTo: assembledURL)

        for seg in segments {
            let segURL = testDir.appendingPathComponent(seg.tempFileName)
            let segHandle = try FileHandle(forReadingFrom: segURL)
            while let chunk = try segHandle.read(upToCount: 32 * 1024), !chunk.isEmpty {
                try assemblyHandle.write(contentsOf: chunk)
            }
            try segHandle.close()
            try fileManager.removeItem(at: segURL)
        }
        try assemblyHandle.synchronize()
        try assemblyHandle.close()

        // Verify assembled file matches original byte for byte
        let assembledData = try Data(contentsOf: assembledURL)
        XCTAssertEqual(assembledData.count, fullData.count)
        XCTAssertEqual(SHA256.hash(data: assembledData), SHA256.hash(data: fullData))
    }
}
