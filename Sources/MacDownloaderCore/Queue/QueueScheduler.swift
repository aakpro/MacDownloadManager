import Foundation
import Combine

/// Central concurrency coordinator and queue scheduler for MacDownloader.
@MainActor
public final class QueueScheduler: ObservableObject {
    @Published public private(set) var items: [DownloadItem] = []
    @Published public private(set) var activeCount: Int = 0
    @Published public private(set) var totalSpeed: Double = 0.0
    private var isInitialized = false

    @Published public var maxConcurrentDownloads: Int = 3 {
        didSet {
            guard isInitialized else { return }
            processQueue()
            persistQueue()
        }
    }
    public var isAutoProcessingEnabled: Bool = true

    public let speedLimiter: SpeedLimiter
    public var categoryManager: CategoryManager
    public var persistenceManager: PersistenceManager

    private var workers: [UUID: DownloadWorker] = [:]
    private var urlSession: URLSession

    // System-level event hooks
    public var onDownloadCompleted: (@Sendable (DownloadItem) -> Void)?
    public var onDownloadFailed: (@Sendable (DownloadItem, Error) -> Void)?

    public init(
        persistenceManager: PersistenceManager = PersistenceManager(),
        categoryManager: CategoryManager = CategoryManager(),
        speedLimiter: SpeedLimiter = SpeedLimiter(),
        urlSession: URLSession? = nil
    ) {
        self.persistenceManager = persistenceManager
        self.categoryManager = categoryManager
        self.speedLimiter = speedLimiter
        if let session = urlSession {
            self.urlSession = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "*/*"
            ]
            self.urlSession = URLSession(configuration: config)
        }

        // Restore persisted queue
        self.items = persistenceManager.loadQueue()

        // Restore persisted preferences
        let prefs = persistenceManager.loadPreferences()
        self.maxConcurrentDownloads = prefs.maxConcurrentDownloads
        self.categoryManager.isAutoCategorizationEnabled = prefs.isAutoCategorizationEnabled

        self.isInitialized = true
    }

    // MARK: - Queue Operations

    /// Ingests an array of URLs into the queue.
    public func add(
        urls: [URL],
        destinationFolder: URL? = nil,
        customCategory: DownloadCategory? = nil,
        startImmediately: Bool = true
    ) {
        var allocatedNamesByFolder: [URL: Set<String>] = [:]
        for item in items {
            allocatedNamesByFolder[item.destinationFolder, default: []].insert(item.filename.lowercased())
        }

        for url in urls {
            let filename = DownloadItem.extractFilename(from: url)
            let category = customCategory ?? DownloadCategory.detect(from: filename)
            let targetFolder = categoryManager.destinationFolder(for: category, customBase: destinationFolder)

            let existingInFolder = allocatedNamesByFolder[targetFolder, default: []]
            let uniqueName = CategoryManager.resolveUniqueFilename(
                in: targetFolder,
                originalFilename: filename,
                existingNames: existingInFolder
            )
            allocatedNamesByFolder[targetFolder, default: []].insert(uniqueName.lowercased())

            let item = DownloadItem(
                url: url,
                filename: uniqueName,
                destinationFolder: targetFolder,
                category: category,
                status: .queued
            )

            items.append(item)
        }

        persistQueue()

        if startImmediately {
            processQueue()
        }
    }

    /// Pauses a specific download.
    public func pause(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .paused
        items[index].speed = 0
        items[index].eta = nil

        if let worker = workers[id] {
            Task {
                await worker.pause()
            }
            workers.removeValue(forKey: id)
        }

        updateAggregateMetrics()
        persistQueue()
        processQueue()
    }

    /// Resumes a specific download.
    public func resume(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .queued
        items[index].errorMessage = nil

        persistQueue()
        processQueue()
    }

    /// Cancels a specific download.
    public func cancel(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .cancelled
        items[index].speed = 0
        items[index].eta = nil

        if let worker = workers[id] {
            Task {
                await worker.cancel()
            }
            workers.removeValue(forKey: id)
        }

        updateAggregateMetrics()
        persistQueue()
        processQueue()
    }

    /// Retries a failed or cancelled task.
    public func retry(id: UUID) {
        resume(id: id)
    }

    /// Manually updates an item's status (useful for completion overrides or testing).
    public func updateItemStatus(id: UUID, status: DownloadStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = status
            if status == .completed {
                items[index].completedAt = Date()
                items[index].speed = 0
                items[index].eta = nil
            }
            updateAggregateMetrics()
            persistQueue()
        }
    }

    /// Removes an item from the queue list and optionally deletes downloaded/partial files.
    public func remove(id: UUID, deleteFiles: Bool = false) {
        remove(ids: [id], deleteFiles: deleteFiles)
    }

    /// Removes multiple items from the queue in batch and optionally deletes downloaded/partial files.
    public func remove(ids: Set<UUID>, deleteFiles: Bool = false) {
        guard !ids.isEmpty else { return }

        let toRemove = items.filter { ids.contains($0.id) }
        guard !toRemove.isEmpty else { return }

        for item in toRemove {
            if let worker = workers[item.id] {
                Task {
                    await worker.cancel()
                }
                workers.removeValue(forKey: item.id)
            }

            if deleteFiles {
                Self.safeDeleteFile(at: item.destinationFileURL)
                Self.safeDeleteFile(at: item.partFileURL)
                for seg in item.segments {
                    Self.safeDeleteFile(at: item.segmentFileURL(for: seg))
                }
            } else {
                if item.status != .completed {
                    Self.safeDeleteFile(at: item.partFileURL)
                    for seg in item.segments {
                        Self.safeDeleteFile(at: item.segmentFileURL(for: seg))
                    }
                }
            }
        }

        items.removeAll(where: { ids.contains($0.id) })

        updateAggregateMetrics()
        persistQueue()
        processQueue()
    }

    /// Safely deletes or moves a file to macOS Trash.
    public static func safeDeleteFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Pauses all active and queued items.
    public func pauseAll() {
        for index in items.indices {
            if items[index].status.canPause {
                items[index].status = .paused
                items[index].speed = 0
                items[index].eta = nil
            }
        }

        for (_, worker) in workers {
            Task {
                await worker.pause()
            }
        }
        workers.removeAll()

        updateAggregateMetrics()
        persistQueue()
    }

    /// Pauses a batch of items.
    public func pause(ids: Set<UUID>) {
        for id in ids {
            pause(id: id)
        }
    }

    /// Resumes a batch of items.
    public func resume(ids: Set<UUID>) {
        for id in ids {
            resume(id: id)
        }
    }

    /// Resumes all paused, failed, or cancelled downloads.
    public func resumeAll() {
        for index in items.indices {
            if items[index].status == .paused || items[index].status == .failed || items[index].status == .cancelled {
                items[index].status = .queued
                items[index].errorMessage = nil
            }
        }

        persistQueue()
        processQueue()
    }

    /// Clears completed downloads from the queue list.
    public func clearCompleted(deleteFiles: Bool = false) {
        let completedIDs = Set(items.filter { $0.status == .completed }.map { $0.id })
        remove(ids: completedIDs, deleteFiles: deleteFiles)
    }

    /// Clears failed and cancelled downloads from the queue.
    public func clearFailed(deleteFiles: Bool = false) {
        let failedIDs = Set(items.filter { $0.status == .failed || $0.status == .cancelled }.map { $0.id })
        remove(ids: failedIDs, deleteFiles: deleteFiles)
    }

    /// Clears all downloads from the queue.
    public func clearAll(deleteFiles: Bool = false) {
        let allIDs = Set(items.map { $0.id })
        remove(ids: allIDs, deleteFiles: deleteFiles)
    }

    /// Dynamically adjusts global speed limit.
    public func setSpeedLimit(bytesPerSecond: Int64) {
        Task {
            await speedLimiter.setLimit(bytesPerSecond: bytesPerSecond)
        }
    }

    // MARK: - Concurrency & Worker Dispatching

    /// Checks worker limits and starts pending queued downloads.
    public func processQueue() {
        guard isAutoProcessingEnabled else {
            updateAggregateMetrics()
            return
        }
        guard workers.count < maxConcurrentDownloads else { return }

        let availableSlots = maxConcurrentDownloads - workers.count

        let queuedItems = items.filter { $0.status == .queued }
        guard !queuedItems.isEmpty else {
            updateAggregateMetrics()
            return
        }

        let toStart = queuedItems.prefix(availableSlots)
        for queuedItem in toStart {
            startWorker(for: queuedItem)
        }

        updateAggregateMetrics()
    }

    private func startWorker(for item: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].errorMessage = nil

        let worker = DownloadWorker(
            item: items[index],
            urlSession: urlSession,
            speedLimiter: speedLimiter
        )
        workers[item.id] = worker

        Task {
            await worker.setCallbacks(
                onProgress: { [weak self] updatedItem in
                    Task { @MainActor [weak self] in
                        self?.handleWorkerProgress(updatedItem)
                    }
                },
                onComplete: { [weak self] completedItem in
                    Task { @MainActor [weak self] in
                        self?.handleWorkerCompletion(completedItem)
                    }
                },
                onFail: { [weak self] failedItem, error in
                    Task { @MainActor [weak self] in
                        self?.handleWorkerFailure(failedItem, error: error)
                    }
                }
            )

            await worker.start()
        }
    }

    private func handleWorkerProgress(_ updatedItem: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == updatedItem.id }) else { return }
        items[index] = updatedItem
        updateAggregateMetrics()
    }

    private func handleWorkerCompletion(_ completedItem: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == completedItem.id }) else { return }
        items[index] = completedItem
        workers.removeValue(forKey: completedItem.id)

        updateAggregateMetrics()
        persistQueue()
        onDownloadCompleted?(completedItem)

        // Automatically pick up next download in queue
        processQueue()
    }

    private func handleWorkerFailure(_ failedItem: DownloadItem, error: Error) {
        guard let index = items.firstIndex(where: { $0.id == failedItem.id }) else { return }
        items[index] = failedItem
        workers.removeValue(forKey: failedItem.id)

        updateAggregateMetrics()
        persistQueue()
        onDownloadFailed?(failedItem, error)

        // Advance to next download
        processQueue()
    }

    private func updateAggregateMetrics() {
        activeCount = workers.count
        totalSpeed = items.filter { $0.status.isActive }.reduce(0.0) { $0 + $1.speed }
    }

    private func persistQueue() {
        try? persistenceManager.saveQueue(items: items)
    }
}
