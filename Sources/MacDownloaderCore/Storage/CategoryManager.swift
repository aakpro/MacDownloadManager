import Foundation

/// Manages category-based directory routing and safe file naming/collision avoidance.
public struct CategoryManager: Sendable {
    public var defaultBaseFolder: URL
    public var isAutoCategorizationEnabled: Bool

    public init(
        defaultBaseFolder: URL? = nil,
        isAutoCategorizationEnabled: Bool = true
    ) {
        if let folder = defaultBaseFolder {
            self.defaultBaseFolder = folder
        } else {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            self.defaultBaseFolder = downloads ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        }
        self.isAutoCategorizationEnabled = isAutoCategorizationEnabled
    }

    /// Resolves the destination directory for a specific category.
    public func destinationFolder(for category: DownloadCategory, customBase: URL? = nil) -> URL {
        let base = customBase ?? defaultBaseFolder
        guard isAutoCategorizationEnabled else {
            return base
        }
        return base.appendingPathComponent(category.subfolderName)
    }

    /// Resolves a non-colliding unique filename in the target directory (e.g. `file (1).zip`).
    /// Resolves a non-colliding unique filename in the target directory (e.g. `file (1).zip`), checking both disk and queued names.
    public static func resolveUniqueFilename(
        in directory: URL,
        originalFilename: String,
        existingNames: Set<String> = []
    ) -> String {
        let fileManager = FileManager.default
        var candidate = originalFilename
        var targetURL = directory.appendingPathComponent(candidate)

        let existsOnDisk = fileManager.fileExists(atPath: targetURL.path)
        let existsInQueue = existingNames.contains(candidate.lowercased())

        guard existsOnDisk || existsInQueue else {
            return candidate
        }

        let name = (originalFilename as NSString).deletingPathExtension
        let ext = (originalFilename as NSString).pathExtension

        var counter = 1
        while fileManager.fileExists(atPath: targetURL.path) || existingNames.contains(candidate.lowercased()) {
            if ext.isEmpty {
                candidate = "\(name) (\(counter))"
            } else {
                candidate = "\(name) (\(counter)).\(ext)"
            }
            targetURL = directory.appendingPathComponent(candidate)
            counter += 1
        }

        return candidate
    }
}
