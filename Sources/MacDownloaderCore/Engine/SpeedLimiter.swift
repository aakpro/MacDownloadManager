import Foundation

/// Thread-safe token-bucket rate limiter for controlling bandwidth usage.
public actor SpeedLimiter {
    /// Maximum allowable transfer rate in bytes per second. 0 represents unlimited.
    public private(set) var maxBytesPerSecond: Int64

    private var availableTokens: Double
    private var lastRefill: Date

    public init(maxBytesPerSecond: Int64 = 0) {
        self.maxBytesPerSecond = maxBytesPerSecond
        self.availableTokens = Double(maxBytesPerSecond)
        self.lastRefill = Date()
    }

    /// Dynamically updates the bandwidth limit.
    public func setLimit(bytesPerSecond: Int64) {
        self.maxBytesPerSecond = bytesPerSecond
        self.availableTokens = Double(bytesPerSecond)
        self.lastRefill = Date()
    }

    /// Throttles execution if the consumed bytes exceed the token bucket allocation.
    public func throttle(bytes: Int64) async {
        guard maxBytesPerSecond > 0 else { return }

        refillTokens()

        availableTokens -= Double(bytes)

        if availableTokens < 0 {
            // Need to sleep until enough tokens accumulate
            let deficit = -availableTokens
            let waitSeconds = deficit / Double(maxBytesPerSecond)
            let waitNanoseconds = UInt64(waitSeconds * 1_000_000_000)

            // Cap sleep time to reasonable interval (max 1s) to stay responsive
            let sleepTime = min(waitNanoseconds, 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepTime)
            refillTokens()
        }
    }

    private func refillTokens() {
        guard maxBytesPerSecond > 0 else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        lastRefill = now

        let newTokens = elapsed * Double(maxBytesPerSecond)
        availableTokens = min(Double(maxBytesPerSecond), availableTokens + newTokens)
    }
}
