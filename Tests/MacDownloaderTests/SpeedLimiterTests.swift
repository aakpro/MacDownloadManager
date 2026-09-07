import XCTest
@testable import MacDownloaderCore

final class SpeedLimiterTests: XCTestCase {

    func testSpeedLimiterUnlimited() async {
        let limiter = SpeedLimiter(maxBytesPerSecond: 0)
        let limit = await limiter.maxBytesPerSecond
        XCTAssertEqual(limit, 0)

        // Should not block or sleep significantly
        let start = Date()
        await limiter.throttle(bytes: 1_000_000)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.1)
    }

    func testSpeedLimiterDynamicUpdate() async {
        let limiter = SpeedLimiter(maxBytesPerSecond: 500_000)
        var limit = await limiter.maxBytesPerSecond
        XCTAssertEqual(limit, 500_000)

        await limiter.setLimit(bytesPerSecond: 2_000_000)
        limit = await limiter.maxBytesPerSecond
        XCTAssertEqual(limit, 2_000_000)
    }
}
