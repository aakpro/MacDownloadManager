import Foundation

/// Logical category for downloaded files, mirroring IDM smart categories.
public enum DownloadCategory: String, Codable, Sendable, CaseIterable {
    case general = "General"
    case documents = "Documents"
    case archives = "Archives"
    case video = "Video"
    case audio = "Audio"
    case programs = "Programs"

    public var subfolderName: String {
        return self.rawValue
    }

    public var iconName: String {
        switch self {
        case .general: return "folder"
        case .documents: return "doc.text"
        case .archives: return "archivebox"
        case .video: return "film"
        case .audio: return "music.note"
        case .programs: return "macwindow"
        }
    }

    /// Automatically detects category from file extension.
    public static func detect(from filename: String) -> DownloadCategory {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf", "doc", "docx", "txt", "rtf", "odt", "epub", "xlsx", "xls", "pptx", "ppt", "md", "csv", "srt", "vtt", "sub", "ass":
            return .documents
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso", "tgz":
            return .archives
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg":
            return .video
        case "mp3", "flac", "wav", "aac", "m4a", "ogg", "wma", "aiff", "alac":
            return .audio
        case "dmg", "pkg", "app", "exe", "deb", "rpm", "bin", "sh":
            return .programs
        default:
            return .general
        }
    }
}
