import Foundation

/// Represents a discrete byte-range segment for parallel multi-connection downloading.
public struct DownloadSegment: Identifiable, Codable, Sendable, Equatable {
    public let id: Int
    public let startByte: Int64
    public let endByte: Int64
    public var downloadedBytes: Int64
    public var isCompleted: Bool
    public var tempFileName: String

    public var totalBytes: Int64 {
        return (endByte - startByte) + 1
    }

    public var progress: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, Double(downloadedBytes) / Double(totalBytes))
    }

    public init(
        id: Int,
        startByte: Int64,
        endByte: Int64,
        downloadedBytes: Int64 = 0,
        isCompleted: Bool = false,
        tempFileName: String
    ) {
        self.id = id
        self.startByte = startByte
        self.endByte = endByte
        self.downloadedBytes = downloadedBytes
        self.isCompleted = isCompleted
        self.tempFileName = tempFileName
    }
}
