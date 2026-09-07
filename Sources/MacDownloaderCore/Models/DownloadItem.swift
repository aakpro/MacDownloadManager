import Foundation

/// Primary data model representing a single download task in MacDownloader.
public struct DownloadItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public var filename: String
    public var destinationFolder: URL
    public var category: DownloadCategory
    public var status: DownloadStatus
    public var totalBytes: Int64
    public var downloadedBytes: Int64
    public var speed: Double // Bytes per second
    public var eta: TimeInterval?
    public var segments: [DownloadSegment]
    public var supportsRanges: Bool
    public var maxSegments: Int
    public var checksum: String?
    public var expectedChecksum: String?
    public var errorMessage: String?
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        url: URL,
        filename: String? = nil,
        destinationFolder: URL,
        category: DownloadCategory? = nil,
        status: DownloadStatus = .queued,
        totalBytes: Int64 = -1,
        downloadedBytes: Int64 = 0,
        speed: Double = 0.0,
        eta: TimeInterval? = nil,
        segments: [DownloadSegment] = [],
        supportsRanges: Bool = false,
        maxSegments: Int = 4,
        checksum: String? = nil,
        expectedChecksum: String? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.url = url
        let derivedFilename = filename ?? Self.extractFilename(from: url)
        self.filename = derivedFilename
        self.destinationFolder = destinationFolder
        self.category = category ?? DownloadCategory.detect(from: derivedFilename)
        self.status = status
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.speed = speed
        self.eta = eta
        self.segments = segments
        self.supportsRanges = supportsRanges
        self.maxSegments = maxSegments
        self.checksum = checksum
        self.expectedChecksum = expectedChecksum
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// Full target file URL at final destination.
    public var destinationFileURL: URL {
        return destinationFolder.appendingPathComponent(filename)
    }

    /// Part file path during active download.
    public var partFileURL: URL {
        return destinationFolder.appendingPathComponent("\(filename).part")
    }

    /// Segment file URL for a given segment.
    public func segmentFileURL(for segment: DownloadSegment) -> URL {
        return destinationFolder.appendingPathComponent(segment.tempFileName)
    }

    /// Progress ratio from 0.0 to 1.0.
    public var progressRatio: Double {
        guard totalBytes > 0 else {
            return status == .completed ? 1.0 : 0.0
        }
        return min(1.0, max(0.0, Double(downloadedBytes) / Double(totalBytes)))
    }

    /// Formatted progress percentage (e.g. "45.6%").
    public var formattedProgress: String {
        guard totalBytes > 0 else {
            return status == .completed ? "100%" : "Indeterminate"
        }
        return String(format: "%.1f%%", progressRatio * 100.0)
    }

    /// Formatted current transfer rate (e.g. "2.4 MB/s").
    public var formattedSpeed: String {
        guard status.isActive && speed > 0 else { return "--" }
        return Self.formatByteCount(Int64(speed)) + "/s"
    }

    /// Formatted size comparison (e.g. "12.4 MB / 50.0 MB").
    public var formattedSize: String {
        let downloadedStr = Self.formatByteCount(downloadedBytes)
        if totalBytes > 0 {
            return "\(downloadedStr) / \(Self.formatByteCount(totalBytes))"
        } else {
            return "\(downloadedStr) / Unknown"
        }
    }

    /// Formatted ETA string (e.g. "02:15" or "45s").
    public var formattedETA: String {
        guard status.isActive, let eta = eta, eta > 0 else { return "--" }
        let totalSeconds = Int(eta)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%02dm %02ds", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }

    public static func formatByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public static func extractFilename(from url: URL) -> String {
        // 1. Check URL query parameters for explicit filenames (e.g. ?filename=..., ?file=...)
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            let candidateKeys = ["filename", "file", "name", "fn", "f", "title"]

            for key in candidateKeys {
                if let item = queryItems.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame }),
                   let val = item.value?.removingPercentEncoding ?? item.value,
                   !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let sanitized = sanitizeFilename(val)
                    if (sanitized as NSString).pathExtension.count > 0 {
                        return sanitized
                    }
                }
            }

            // Check response-content-disposition in query (common in S3/CloudFront)
            if let rcd = queryItems.first(where: { $0.name.caseInsensitiveCompare("response-content-disposition") == .orderedSame })?.value {
                if let parsed = extractFilenameFromContentDisposition(rcd) {
                    return sanitizeFilename(parsed)
                }
            }
        }

        // 2. Check lastPathComponent of the URL path
        let lastComponent = url.lastPathComponent
        if !lastComponent.isEmpty && lastComponent != "/" {
            let clean = lastComponent.components(separatedBy: "?").first ?? lastComponent
            let decoded = clean.removingPercentEncoding ?? clean
            let ext = (decoded as NSString).pathExtension.lowercased()

            // Script extensions should not be preferred over query param names
            let scriptExtensions: Set<String> = ["php", "asp", "aspx", "jsp", "cgi", "cfm"]
            if !ext.isEmpty && !scriptExtensions.contains(ext) {
                return sanitizeFilename(decoded)
            }

            // If lastPathComponent has no valid extension, check query param without extension
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                let candidateKeys = ["filename", "file", "name", "fn", "title"]
                for key in candidateKeys {
                    if let item = queryItems.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame }),
                       let val = item.value?.removingPercentEncoding ?? item.value,
                       !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return sanitizeFilename(val)
                    }
                }
            }

            if !decoded.isEmpty {
                return sanitizeFilename(decoded)
            }
        }

        // 3. Fallback to host or default identifier
        if let host = url.host, !host.isEmpty {
            return "download_\(host)"
        }
        return "download_\(UUID().uuidString.prefix(8))"
    }

    public static func sanitizeFilename(_ name: String) -> String {
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "/", with: "_")
        clean = clean.replacingOccurrences(of: ":", with: "_")
        clean = clean.replacingOccurrences(of: "\0", with: "")
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: "\" '"))
        return clean.isEmpty ? "download" : clean
    }

    public static func extractFilenameFromContentDisposition(_ header: String) -> String? {
        let components = header.components(separatedBy: ";")
        for comp in components {
            let trimmed = comp.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().starts(with: "filename*=") {
                let val = trimmed.dropFirst("filename*=".count)
                // e.g. UTF-8''example.zip
                if let utfPart = val.components(separatedBy: "''").last {
                    let decoded = utfPart.removingPercentEncoding ?? utfPart
                    return decoded.trimmingCharacters(in: CharacterSet(charactersIn: "\" '"))
                }
            } else if trimmed.lowercased().starts(with: "filename=") {
                let val = trimmed.dropFirst("filename=".count)
                let decoded = val.removingPercentEncoding ?? String(val)
                return decoded.trimmingCharacters(in: CharacterSet(charactersIn: "\" '"))
            }
        }
        return nil
    }
}
