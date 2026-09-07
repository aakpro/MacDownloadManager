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
    case failed = "Failed"

    public var id: String { rawValue }
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var scheduler: QueueScheduler
    @Published public var clipboardMonitor: ClipboardMonitor
    @Published public var notificationManager: NotificationManager
    @Published public var timeScheduler: QueueTimeScheduler

    // UI Navigation & Filters
    @Published public var selectedCategory: DownloadCategory? = nil
    @Published public var selectedStatus: StatusFilter = .all
    @Published public var searchQuery: String = ""

    // Multi-Selection State
    @Published public var selectedItemIDs: Set<UUID> = []

    // Sheet Presentations
    @Published public var isShowingAddSheet: Bool = false
    @Published public var isShowingSettingsSheet: Bool = false
    @Published public var isShowingSchedulerSheet: Bool = false
    @Published public var initialAddInput: String = ""

    // Prompt for clipboard capture
    @Published public var detectedClipboardURLs: [URL]? = nil

    private var cancellables = Set<AnyCancellable>()

    public init(scheduler: QueueScheduler? = nil) {
        let sched = scheduler ?? QueueScheduler()
        self.scheduler = sched
        self.timeScheduler = QueueTimeScheduler(scheduler: sched)
        self.clipboardMonitor = ClipboardMonitor(enabled: true)
        self.notificationManager = NotificationManager.shared

        setupEventHooks()

        // Forward scheduler updates to trigger UI refresh and system integrations
        sched.objectWillChange.sink { [weak self] in
            guard let self = self else { return }
            self.objectWillChange.send()
            self.updateSystemIntegrations()
        }.store(in: &cancellables)

        clipboardMonitor.onURLsDetected = { [weak self] urls in
            self?.detectedClipboardURLs = urls
        }
    }

    public func updateSystemIntegrations() {
        let activeItems = scheduler.items.filter { $0.status.isActive }
        let activeCount = activeItems.count
        let totalBytes = activeItems.reduce(0) { $0 + max(0, $1.totalBytes) }
        let downloadedBytes = activeItems.reduce(0) { $0 + $1.downloadedBytes }
        let ratio = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0.0

        DockTileManager.shared.update(activeCount: activeCount, progressRatio: ratio)
        PowerManager.shared.updateAssertion(hasActiveDownloads: activeCount > 0)
    }

    private func setupEventHooks() {
        scheduler.onDownloadCompleted = { [weak self] item in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.notificationManager.playCompletionSound(isSuccess: true)
                self.notificationManager.postDownloadCompletedNotification(for: item)

                let remaining = self.scheduler.items.filter { $0.status.isActive || $0.status == .queued }
                if remaining.isEmpty {
                    PowerManager.shared.handleQueueCompleted()
                }
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
        case .failed:
            list = list.filter { $0.status == .failed || $0.status == .cancelled }
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

    // MARK: - Selection Management

    public func toggleSelection(for itemID: UUID) {
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }
    }

    public func selectOnly(_ itemID: UUID) {
        selectedItemIDs = [itemID]
    }

    public func selectAll() {
        selectedItemIDs = Set(filteredItems.map { $0.id })
    }

    public func deselectAll() {
        selectedItemIDs.removeAll()
    }

    public func isSelected(_ itemID: UUID) -> Bool {
        selectedItemIDs.contains(itemID)
    }

    // MARK: - Batch & Individual Actions

    public func deleteSelected(deleteFiles: Bool = false) {
        guard !selectedItemIDs.isEmpty else { return }
        scheduler.remove(ids: selectedItemIDs, deleteFiles: deleteFiles)
        selectedItemIDs.removeAll()
    }

    public func pauseSelected() {
        scheduler.pause(ids: selectedItemIDs)
    }

    public func resumeSelected() {
        scheduler.resume(ids: selectedItemIDs)
    }

    public func remove(item: DownloadItem, deleteFiles: Bool = false) {
        selectedItemIDs.remove(item.id)
        scheduler.remove(id: item.id, deleteFiles: deleteFiles)
    }

    public func clearCompleted(deleteFiles: Bool = false) {
        selectedItemIDs.subtract(scheduler.items.filter { $0.status == .completed }.map { $0.id })
        scheduler.clearCompleted(deleteFiles: deleteFiles)
    }

    public func clearFailed(deleteFiles: Bool = false) {
        selectedItemIDs.subtract(scheduler.items.filter { $0.status == .failed || $0.status == .cancelled }.map { $0.id })
        scheduler.clearFailed(deleteFiles: deleteFiles)
    }

    public func clearAll(deleteFiles: Bool = false) {
        selectedItemIDs.removeAll()
        scheduler.clearAll(deleteFiles: deleteFiles)
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
