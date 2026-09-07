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

    func testExtensionFilterWithQueryParameters() {
        let input = """
        https://git.ir/api/post/get-download-links/XQy3g/?token=123&filename=lesson01.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=456&filename=lesson01.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=789&filename=lesson02.mp4
        """
        let mp4Only = URLParser.parse(text: input, filterExtension: "mp4")
        XCTAssertEqual(mp4Only.count, 2)

        let srtOnly = URLParser.parse(text: input, filterExtension: "srt")
        XCTAssertEqual(srtOnly.count, 1)
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

    func testUserDataBatchParsingAndFilenameExtraction() {
        let input = """
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=001-Introduction-07tg-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=002-Understanding%20the%20Roles%20and%20Responsibilities-jtiX-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=003-Evolving%20Skill%20Sets%20and%20Mindsets-dc9Y-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=004-Decision%20Making%20Stakeholders%20and%20Challenges-8JIP-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=005-Introduction%20of%20a%20Software%20Architect%20Mindset-r4Ct-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=006-Overview%20of%20Architectural%20Patterns-Fk1I-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=007-Trade%20offs%20in%20Choosing%20a%20Software%20Pattern-IbjZ-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=008-Understanding%20Business%20Domains%20and%20Stakeholders-T2YB-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=009-Defining%20the%20Solution%20Architecture-JqSi-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=010-Balancing%20Constraints%20and%20Making%20Trade%20offs-9VnC-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=011-Working%20Across%20Project%20Layers-Bk8X-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=012-Monolithic%20Architecture-Z4cC-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=013-Layered%20Architecture-ctD1-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=014-Microservices%20Architecture-vTBM-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=015-Micro%20Frontend%20Architecture-NAIb-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=016-Event%20Driven%20Architecture-M6jM-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=017-Serverless%20Architecture-qPwb-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=018-Architectural%20Components%20Decomposition%20and%20Building%20Blocks-vyQD-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=019-Communication%20Styles%20Synchronous%20vs%20Asynchronous-gpzH-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=020-Data%20and%20Database%20Models-e0Kv-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=021-Functional%20and%20Non%20Functional%20Requirements-DTpk-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=022-APIs%20and%20Integration-38ly-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=023-Understanding%20the%20Business%20Domain%20and%20Event%20Storming-8vyp-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=024-Domain%20Driven%20Design%20DDD-zKKp-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=025-Strategic%20Design%20in%20DDD%20Bounded%20Contexts%20and%20Context%20Mapping-M6ZU-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=026-Component%20Discovery%20and%20Decomposition-F32v-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=027-The%20C4%20Model%20for%20Visualizing%20Architecture-InLI-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=028-Tech%20Stack%20Alignment%20with%20Business%20Goals-FnWh-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=029-From%20Business%20Goals%20to%20Architecture%20Bridging%20the%20Gap-eWTS-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=030-Introduction-TGEK-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=031-Understanding%20the%20Business%20Context%20and%20Requirements-LJDs-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=032-Mapping%20Business%20Requirements%20to%20Domain%20Functionality-wPsD-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=033-Component%20Discovery%20and%20Defining%20Software%20Boundaries-UEWO-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=034-Exploring%20Trade%20offs%20in%20Architectural%20Decisions-G2tP-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=035-Designing%20Communication%20and%20Data%20Flow-FjYx-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=036-Defining%20Databases%20and%20Data%20Storage%20Strategy-cUD1-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=037-Integrating%20Components%20into%20a%20Complete%20Software%20Architecture-xl9w-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=4f82f13e677e469cad78df7397e0fad8&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=038-Conclusion-zS1c-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=001-Introduction-07tg-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=002-Understanding%20the%20Roles%20and%20Responsibilities-jtiX-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=003-Evolving%20Skill%20Sets%20and%20Mindsets-dc9Y-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=004-Decision%20Making%20Stakeholders%20and%20Challenges-8JIP-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=005-Introduction%20of%20a%20Software%20Architect%20Mindset-r4Ct-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=006-Overview%20of%20Architectural%20Patterns-Fk1I-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=007-Trade%20offs%20in%20Choosing%20a%20Software%20Pattern-IbjZ-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=008-Understanding%20Business%20Domains%20and%20Stakeholders-T2YB-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=009-Defining%20the%20Solution%20Architecture-JqSi-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=010-Balancing%20Constraints%20and%20Making%20Trade%20offs-9VnC-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=011-Working%20Across%20Project%20Layers-Bk8X-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=012-Monolithic%20Architecture-Z4cC-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=013-Layered%20Architecture-ctD1-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=014-Microservices%20Architecture-vTBM-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=015-Micro%20Frontend%20Architecture-NAIb-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=016-Event%20Driven%20Architecture-M6jM-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=017-Serverless%20Architecture-qPwb-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=018-Architectural%20Components%20Decomposition%20and%20Building%20Blocks-vyQD-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=019-Communication%20Styles%20Synchronous%20vs%20Asynchronous-gpzH-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=020-Data%20and%20Database%20Models-e0Kv-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=021-Functional%20and%20Non%20Functional%20Requirements-DTpk-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=022-APIs%20and%20Integration-38ly-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=023-Understanding%20the%20Business%20Domain%20and%20Event%20Storming-8vyp-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=024-Domain%20Driven%20Design%20DDD-zKKp-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=025-Strategic%20Design%20in%20DDD%20Bounded%20Contexts%20and%20Context%20Mapping-M6ZU-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=026-Component%20Discovery%20and%20Decomposition-F32v-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=027-The%20C4%20Model%20for%20Visualizing%20Architecture-InLI-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=028-Tech%20Stack%20Alignment%20with%20Business%20Goals-FnWh-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=029-From%20Business%20Goals%20to%20Architecture%20Bridging%20the%20Gap-eWTS-git.ir.srt
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=030-Introduction-TGEK-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=031-Understanding%20the%20Business%20Context%20and%20Requirements-LJDs-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=032-Mapping%20Business%20Requirements%20to%20Domain%20Functionality-wPsD-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=033-Component%20Discovery%20and%20Defining%20Software%20Boundaries-UEWO-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=034-Exploring%20Trade%20offs%20in%20Architectural%20Decisions-G2tP-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=035-Designing%20Communication%20and%20Data%20Flow-FjYx-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=036-Defining%20Databases%20and%20Data%20Storage%20Strategy-cUD1-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=037-Integrating%20Components%20into%20a%20Complete%20Software%20Architecture-xl9w-git.ir.mp4
        https://git.ir/api/post/get-download-links/XQy3g/?token=e2030d4d2dac4d7f959f4e0488260be7&hash=GDdJ6RW3ZQ92wz4xmAMabNgL9LQnpXYkPj0L1Kv5O7VBErln8e&filename=038-Conclusion-zS1c-git.ir.mp4
        """

        let allURLs = URLParser.parse(text: input)
        XCTAssertEqual(allURLs.count, 76)

        let mp4URLs = URLParser.parse(text: input, filterExtension: "mp4")
        XCTAssertEqual(mp4URLs.count, 47)

        let srtURLs = URLParser.parse(text: input, filterExtension: "srt")
        XCTAssertEqual(srtURLs.count, 29)

        // Verify correct filenames extracted
        let firstFilename = DownloadItem.extractFilename(from: mp4URLs[0])
        XCTAssertEqual(firstFilename, "001-Introduction-07tg-git.ir.mp4")

        let secondFilename = DownloadItem.extractFilename(from: mp4URLs[1])
        XCTAssertEqual(secondFilename, "002-Understanding the Roles and Responsibilities-jtiX-git.ir.mp4")

        let lastSrtFilename = DownloadItem.extractFilename(from: srtURLs[28])
        XCTAssertEqual(lastSrtFilename, "029-From Business Goals to Architecture Bridging the Gap-eWTS-git.ir.srt")
    }
}
