import Foundation

/// Preferences model persisted across application sessions.
public struct AppPreferences: Codable, Sendable {
    public var maxConcurrentDownloads: Int
    public var speedLimitBytesPerSec: Int64
    public var isAutoCategorizationEnabled: Bool
    public var defaultDestinationPath: String?

    public init(
        maxConcurrentDownloads: Int = 3,
        speedLimitBytesPerSec: Int64 = 0,
        isAutoCategorizationEnabled: Bool = true,
        defaultDestinationPath: String? = nil
    ) {
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.speedLimitBytesPerSec = speedLimitBytesPerSec
        self.isAutoCategorizationEnabled = isAutoCategorizationEnabled
        self.defaultDestinationPath = defaultDestinationPath
    }
}

/// Manages persistence of queue state and preferences to disk.
public struct PersistenceManager: Sendable {
    public let storageDirectory: URL

    public var queueFileURL: URL {
        return storageDirectory.appendingPathComponent("queue.json")
    }

    public var preferencesFileURL: URL {
        return storageDirectory.appendingPathComponent("preferences.json")
    }

    public init(customStorageDirectory: URL? = nil) {
        if let customDir = customStorageDirectory {
            self.storageDirectory = customDir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let dir = (appSupport ?? URL(fileURLWithPath: NSHomeDirectory())).appendingPathComponent("MacDownloader")
            self.storageDirectory = dir
        }
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    /// Saves the current list of download items to disk.
    public func saveQueue(items: [DownloadItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(items)
        try data.write(to: queueFileURL, options: [.atomic])
    }

    /// Loads persisted download items, resetting interrupted active states.
    public func loadQueue() -> [DownloadItem] {
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: queueFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([DownloadItem].self, from: data)

            // Reset any item that was interrupted during app shutdown
            return items.map { item in
                var restored = item
                if restored.status.isActive {
                    restored.status = .paused
                    restored.speed = 0
                    restored.eta = nil
                }
                return restored
            }
        } catch {
            return []
        }
    }

    /// Saves user preferences to disk.
    public func savePreferences(_ preferences: AppPreferences) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(preferences)
        try data.write(to: preferencesFileURL, options: [.atomic])
    }

    /// Loads persisted preferences.
    public func loadPreferences() -> AppPreferences {
        guard FileManager.default.fileExists(atPath: preferencesFileURL.path) else {
            return AppPreferences()
        }

        do {
            let data = try Data(contentsOf: preferencesFileURL)
            return try JSONDecoder().decode(AppPreferences.self, from: data)
        } catch {
            return AppPreferences()
        }
    }
}
