import Foundation
import SwiftUI
import AppKit
import Combine
import MacDownloaderCore

public enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"

    public var id: String { rawValue }
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var scheduler: QueueScheduler
    @Published public var clipboardMonitor: ClipboardMonitor
    @Published public var notificationManager: NotificationManager

    // UI Navigation & Filters
    @Published public var selectedCategory: DownloadCategory? = nil
    @Published public var selectedStatus: StatusFilter = .all
    @Published public var searchQuery: String = ""

    // Sheet Presentations
    @Published public var isShowingAddSheet: Bool = false
    @Published public var isShowingSettingsSheet: Bool = false
    @Published public var initialAddInput: String = ""

    // Prompt for clipboard capture
    @Published public var detectedClipboardURLs: [URL]? = nil

    private var cancellables = Set<AnyCancellable>()

    public init(scheduler: QueueScheduler? = nil) {
        let sched = scheduler ?? QueueScheduler()
        self.scheduler = sched
        self.clipboardMonitor = ClipboardMonitor(enabled: true)
        self.notificationManager = NotificationManager.shared

        setupEventHooks()

        // Forward scheduler updates to trigger UI refresh
        sched.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        clipboardMonitor.onURLsDetected = { [weak self] urls in
            self?.detectedClipboardURLs = urls
        }
    }

    private func setupEventHooks() {
        scheduler.onDownloadCompleted = { [weak self] item in
            Task { @MainActor [weak self] in
                self?.notificationManager.playCompletionSound(isSuccess: true)
                self?.notificationManager.postDownloadCompletedNotification(for: item)
            }
        }

        scheduler.onDownloadFailed = { [weak self] item, error in
            Task { @MainActor [weak self] in
                self?.notificationManager.playCompletionSound(isSuccess: false)
                self?.notificationManager.postDownloadFailedNotification(for: item, error: error)
            }
        }
    }

    // MARK: - Filtered Queue

    public var filteredItems: [DownloadItem] {
        var list = scheduler.items

        // Category filter
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }

        // Status filter
        switch selectedStatus {
        case .all:
            break
        case .downloading:
            list = list.filter { $0.status.isActive }
        case .paused:
            list = list.filter { $0.status == .paused }
        case .completed:
            list = list.filter { $0.status == .completed }
        }

        // Search query
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.filename.lowercased().contains(query) ||
                $0.url.absoluteString.lowercased().contains(query)
            }
        }

        return list
    }

    public func count(for category: DownloadCategory?) -> Int {
        if let cat = category {
            return scheduler.items.filter { $0.category == cat }.count
        }
        return scheduler.items.count
    }

    // MARK: - Actions

    public func addDownloads(
        rawText: String,
        destinationFolder: URL? = nil,
        customCategory: DownloadCategory? = nil,
        filterExtension: String? = nil,
        startImmediately: Bool = true
    ) {
        let urls = URLParser.parse(text: rawText, filterExtension: filterExtension)
        guard !urls.isEmpty else { return }

        scheduler.add(
            urls: urls,
            destinationFolder: destinationFolder,
            customCategory: customCategory,
            startImmediately: startImmediately
        )
    }

    public func revealInFinder(for item: DownloadItem) {
        let targetURL = item.status == .completed ? item.destinationFileURL : item.partFileURL
        if FileManager.default.fileExists(atPath: targetURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
        } else if FileManager.default.fileExists(atPath: item.destinationFolder.path) {
            NSWorkspace.shared.activateFileViewerSelecting([item.destinationFolder])
        }
    }

    public func copyDownloadLink(for item: DownloadItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
    }
}
