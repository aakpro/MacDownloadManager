import XCTest
@testable import MacDownloaderCore

final class NativeHostMessageTests: XCTestCase {

    func testRequestSerializationAndParsing() throws {
        let request = NativeDownloadRequest(
            action: "download",
            url: "https://example.com/movie.mp4",
            filename: "movie.mp4",
            referer: "https://example.com/",
            cookies: "session=abc"
        )

        let data = try NativeMessagingFraming.serializeRequest(request)
        XCTAssertGreaterThan(data.count, 4)

        // Read length prefix
        let length: UInt32 = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(Int(length), data.count - 4)

        // Decode payload
        let payload = data.suffix(from: 4)
        let decoded = try JSONDecoder().decode(NativeDownloadRequest.self, from: payload)
        XCTAssertEqual(decoded.action, "download")
        XCTAssertEqual(decoded.url, "https://example.com/movie.mp4")
        XCTAssertEqual(decoded.filename, "movie.mp4")
        XCTAssertEqual(decoded.referer, "https://example.com/")
    }

    func testBatchRequestSerialization() throws {
        let batchRequest = NativeDownloadRequest(
            action: "batch_download",
            urls: [
                "https://example.com/file1.zip",
                "https://example.com/file2.zip"
            ]
        )

        let data = try NativeMessagingFraming.serializeRequest(batchRequest)
        let payload = data.suffix(from: 4)
        let decoded = try JSONDecoder().decode(NativeDownloadRequest.self, from: payload)
        XCTAssertEqual(decoded.action, "batch_download")
        XCTAssertEqual(decoded.urls?.count, 2)
    }

    func testResponseSerialization() throws {
        let response = NativeHostResponse(status: "ok", message: "Download queued", addedCount: 1)
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(NativeHostResponse.self, from: encoded)

        XCTAssertEqual(decoded.status, "ok")
        XCTAssertEqual(decoded.message, "Download queued")
        XCTAssertEqual(decoded.addedCount, 1)
    }
}
