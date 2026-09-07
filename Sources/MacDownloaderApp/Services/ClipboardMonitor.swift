import Foundation
import AppKit
import MacDownloaderCore

/// Background watcher for macOS system pasteboard to catch copied download links (IDM style).
@MainActor
public final class ClipboardMonitor: ObservableObject {
    @Published public var detectedURLs: [URL] = []
    @Published public var isMonitoringEnabled: Bool = false {
        didSet {
            if isMonitoringEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var ignoredStrings: Set<String> = []

    public var onURLsDetected: (([URL]) -> Void)?

    public init(enabled: Bool = false) {
        self.isMonitoringEnabled = enabled
        if enabled {
            startMonitoring()
        }
    }

    public func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForCopiedLinks()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func ignoreURLString(_ string: String) {
        ignoredStrings.insert(string)
    }

    private func checkForCopiedLinks() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let copiedString = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !copiedString.isEmpty,
              !ignoredStrings.contains(copiedString) else {
            return
        }

        let parsed = URLParser.parse(text: copiedString)
        guard !parsed.isEmpty else { return }

        // Filter for URLs that look like downloadable files or media
        let downloadableExtensions: Set<String> = [
            "zip", "rar", "7z", "tar", "gz", "iso", "dmg", "pkg", "exe",
            "pdf", "docx", "xlsx", "epub", "mp4", "mkv", "mov", "webm",
            "mp3", "flac", "wav", "aac", "srt", "vtt", "sub", "ass"
        ]

        let validDownloads = parsed.filter { url in
            let pathExt = url.pathExtension.lowercased()
            let detectedName = DownloadItem.extractFilename(from: url)
            let detectedExt = (detectedName as NSString).pathExtension.lowercased()

            let hasDownloadableExt = downloadableExtensions.contains(pathExt) || downloadableExtensions.contains(detectedExt)
            let hasDownloadEndpoint = url.path.lowercased().contains("download")

            return hasDownloadableExt || hasDownloadEndpoint
        }

        if !validDownloads.isEmpty {
            self.detectedURLs = validDownloads
            self.onURLsDetected?(validDownloads)
        }
    }
}
