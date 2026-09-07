import XCTest
@testable import MacDownloaderCore

final class URLParserTests: XCTestCase {

    func testSingleURLParsing() {
        let input = "https://example.com/files/archive.zip"
        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "https://example.com/files/archive.zip")
    }

    func testCommaSeparatedURLs() {
        let input = "https://example.com/file1.zip, https://example.com/file2.zip, https://example.com/file3.zip"
        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/file1.zip")
        XCTAssertEqual(urls[1].absoluteString, "https://example.com/file2.zip")
        XCTAssertEqual(urls[2].absoluteString, "https://example.com/file3.zip")
    }

    func testNewlineSeparatedURLs() {
        let input = """
        https://cdn.test.org/doc1.pdf
        https://cdn.test.org/doc2.pdf
        https://cdn.test.org/doc3.pdf
        """
        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls[1].absoluteString, "https://cdn.test.org/doc2.pdf")
    }

    func testMixedDelimitersAndSurroundingPunctuation() {
        let input = """
        "https://example.com/a.zip", <https://example.com/b.zip>; https://example.com/c.zip
        'https://example.com/d.zip'
        """
        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 4)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/a.zip")
        XCTAssertEqual(urls[1].absoluteString, "https://example.com/b.zip")
        XCTAssertEqual(urls[2].absoluteString, "https://example.com/c.zip")
        XCTAssertEqual(urls[3].absoluteString, "https://example.com/d.zip")
    }

    func testBatchPatternExpansionWithZeroPadding() {
        let input = "https://example.com/episodes/show_ep[01-05].mp4"
        let expanded = URLParser.expandPattern(input)
        XCTAssertEqual(expanded.count, 5)
        XCTAssertEqual(expanded[0], "https://example.com/episodes/show_ep01.mp4")
        XCTAssertEqual(expanded[4], "https://example.com/episodes/show_ep05.mp4")

        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 5)
        XCTAssertEqual(urls[2].absoluteString, "https://example.com/episodes/show_ep03.mp4")
    }

    func testBatchPatternExpansionWithoutZeroPadding() {
        let input = "https://example.com/parts/part[1-3].tar"
        let expanded = URLParser.expandPattern(input)
        XCTAssertEqual(expanded.count, 3)
        XCTAssertEqual(expanded[0], "https://example.com/parts/part1.tar")
        XCTAssertEqual(expanded[1], "https://example.com/parts/part2.tar")
        XCTAssertEqual(expanded[2], "https://example.com/parts/part3.tar")
    }

    func testExtensionFilter() {
        let input = """
        https://example.com/video.mp4
        https://example.com/document.pdf
        https://example.com/song.mp3
        https://example.com/movie.mp4
        """
        let mp4Only = URLParser.parse(text: input, filterExtension: "mp4")
        XCTAssertEqual(mp4Only.count, 2)
        XCTAssertEqual(mp4Only[0].lastPathComponent, "video.mp4")
        XCTAssertEqual(mp4Only[1].lastPathComponent, "movie.mp4")
    }

    func testInvalidSchemeIgnored() {
        let input = "ftp://example.com/file.zip, not_a_url, mailto:test@example.com, https://valid.com/file.dmg"
        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "https://valid.com/file.dmg")
    }

    func testDeduplication() {
        let input = "https://example.com/file.zip, https://example.com/file.zip, https://example.com/file.zip"
        let urls = URLParser.parse(text: input)
        XCTAssertEqual(urls.count, 1)
    }
}
