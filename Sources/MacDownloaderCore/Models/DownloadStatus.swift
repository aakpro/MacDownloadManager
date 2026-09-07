import Foundation

/// Represents the execution state of an individual download item.
public enum DownloadStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case connecting
    case downloading
    case paused
    case completed
    case failed
    case cancelled

    public var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .connecting: return "Connecting"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    public var isTerminal: Bool {
        return self == .completed || self == .cancelled || self == .failed
    }

    public var isActive: Bool {
        return self == .connecting || self == .downloading
    }

    public var canPause: Bool {
        return self == .connecting || self == .downloading || self == .queued
    }

    public var canResume: Bool {
        return self == .paused || self == .failed || self == .cancelled
    }
}
