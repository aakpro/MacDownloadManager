import Foundation

/// Incoming JSON payload from browser extension via Native Messaging or URL scheme.
public struct NativeDownloadRequest: Codable, Sendable {
    public let action: String // "download", "batch_download", "ping"
    public let url: String?
    public let urls: [String]?
    public let filename: String?
    public let referer: String?
    public let cookies: String?

    public init(
        action: String,
        url: String? = nil,
        urls: [String]? = nil,
        filename: String? = nil,
        referer: String? = nil,
        cookies: String? = nil
    ) {
        self.action = action
        self.url = url
        self.urls = urls
        self.filename = filename
        self.referer = referer
        self.cookies = cookies
    }
}

/// Outgoing JSON response back to browser extension via stdio.
public struct NativeHostResponse: Codable, Sendable {
    public let status: String // "ok", "error", "pong"
    public let message: String?
    public let addedCount: Int?

    public init(status: String, message: String? = nil, addedCount: Int? = nil) {
        self.status = status
        self.message = message
        self.addedCount = addedCount
    }
}

/// Stdio framing utility for Chrome/Firefox/Safari Native Messaging protocol (32-bit little-endian length prefix).
public enum NativeMessagingFraming {

    /// Reads a length-prefixed JSON message from FileHandle.
    public static func readMessage(from handle: FileHandle = .standardInput) -> NativeDownloadRequest? {
        // Read 4-byte length prefix (UInt32, native byte order / little endian on macOS)
        guard let lengthData = try? handle.read(upToCount: 4), lengthData.count == 4 else {
            return nil
        }

        let messageLength: UInt32 = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard messageLength > 0, messageLength <= 10 * 1024 * 1024 else { // 10MB safety ceiling
            return nil
        }

        guard let payloadData = try? handle.read(upToCount: Int(messageLength)),
              payloadData.count == Int(messageLength) else {
            return nil
        }

        return try? JSONDecoder().decode(NativeDownloadRequest.self, from: payloadData)
    }

    /// Writes a length-prefixed JSON response to FileHandle.
    public static func writeResponse(_ response: NativeHostResponse, to handle: FileHandle = .standardOutput) {
        guard let payloadData = try? JSONEncoder().encode(response) else { return }

        var messageLength = UInt32(payloadData.count)
        var lengthData = Data(bytes: &messageLength, count: MemoryLayout<UInt32>.size)
        lengthData.append(payloadData)

        try? handle.write(contentsOf: lengthData)
    }

    /// Serializes a request to length-prefixed data (useful for testing and extension communication).
    public static func serializeRequest(_ request: NativeDownloadRequest) throws -> Data {
        let payload = try JSONEncoder().encode(request)
        var length = UInt32(payload.count)
        var result = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        result.append(payload)
        return result
    }
}
