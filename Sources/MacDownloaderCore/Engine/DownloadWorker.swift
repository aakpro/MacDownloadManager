import Foundation

/// Core network worker responsible for executing a single download item using resumable streams and byte ranges.
public actor DownloadWorker {
    public let itemID: UUID
    public private(set) var item: DownloadItem

    private var activeTask: Task<Void, Error>?
    private let urlSession: URLSession
    private let speedLimiter: SpeedLimiter?

    // Progress tracking
    private var lastSpeedCalculationTime: Date = Date()
    private var bytesSinceLastSpeedCalculation: Int64 = 0
    private var recentSpeeds: [Double] = []

    // Callbacks
    private var onProgressUpdate: (@Sendable (DownloadItem) -> Void)?
    private var onCompletion: (@Sendable (DownloadItem) -> Void)?
    private var onFailure: (@Sendable (DownloadItem, Error) -> Void)?

    public init(
        item: DownloadItem,
        urlSession: URLSession = .shared,
        speedLimiter: SpeedLimiter? = nil
    ) {
        self.itemID = item.id
        self.item = item
        self.urlSession = urlSession
        self.speedLimiter = speedLimiter
    }

    /// Registers event callbacks.
    public func setCallbacks(
        onProgress: (@Sendable (DownloadItem) -> Void)? = nil,
        onComplete: (@Sendable (DownloadItem) -> Void)? = nil,
        onFail: (@Sendable (DownloadItem, Error) -> Void)? = nil
    ) {
        self.onProgressUpdate = onProgress
        self.onCompletion = onComplete
        self.onFailure = onFail
    }

    /// Starts or resumes the download process.
    public func start() {
        guard !item.status.isActive else { return }

        item.status = .connecting
        item.errorMessage = nil
        onProgressUpdate?(item)

        activeTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.executeDownload()
            } catch is CancellationError {
                await self.handlePauseOrCancel()
            } catch {
                await self.handleFailure(error: error)
            }
        }
    }

    /// Pauses the download, retaining partial files for resumption.
    public func pause() {
        guard item.status.canPause else { return }
        item.status = .paused
        item.speed = 0
        item.eta = nil
        activeTask?.cancel()
        activeTask = nil
        onProgressUpdate?(item)
    }

    /// Cancels download and cleans up partial files.
    public func cancel() {
        item.status = .cancelled
        item.speed = 0
        item.eta = nil
        activeTask?.cancel()
        activeTask = nil

        // Clean up partial file
        try? FileManager.default.removeItem(at: item.partFileURL)
        onProgressUpdate?(item)
    }

    // MARK: - Internal Download Execution

    private func executeDownload() async throws {
        let fileManager = FileManager.default

        // Ensure destination directory exists
        try fileManager.createDirectory(at: item.destinationFolder, withIntermediateDirectories: true)

        let partURL = item.partFileURL
        var existingBytes: Int64 = 0
        if fileManager.fileExists(atPath: partURL.path) {
            if let attrs = try? fileManager.attributesOfItem(atPath: partURL.path),
               let size = attrs[.size] as? Int64 {
                existingBytes = size
            }
        }

        var request = URLRequest(url: item.url)
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
        }

        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "MacDownloaderHTTPError",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP Server returned status code \(httpResponse.statusCode)"]
            )
        }

        // Determine resume capability & Content-Length
        let isPartial = httpResponse.statusCode == 206
        let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
        item.supportsRanges = isPartial || acceptRanges

        if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition") {
            if let parsedName = extractFilenameFromContentDisposition(contentDisposition) {
                item.filename = parsedName
            }
        }

        let responseLength = httpResponse.expectedContentLength
        if responseLength > 0 {
            item.totalBytes = isPartial ? (existingBytes + responseLength) : responseLength
        }

        // Initialize file handle
        let fileHandle: FileHandle
        if isPartial && existingBytes > 0 {
            item.downloadedBytes = existingBytes
            fileHandle = try FileHandle(forWritingTo: partURL)
            try fileHandle.seekToEnd()
        } else {
            // New download or server ignored Range request
            item.downloadedBytes = 0
            fileManager.createFile(atPath: partURL.path, contents: nil)
            fileHandle = try FileHandle(forWritingTo: partURL)
        }

        item.status = .downloading
        lastSpeedCalculationTime = Date()
        bytesSinceLastSpeedCalculation = 0

        // Stream data chunks
        var chunkBuffer = Data()
        let bufferThreshold = 64 * 1024 // 64 KB write buffer

        for try await byte in asyncBytes {
            try Task.checkCancellation()

            chunkBuffer.append(byte)
            item.downloadedBytes += 1
            bytesSinceLastSpeedCalculation += 1

            if chunkBuffer.count >= bufferThreshold {
                try fileHandle.write(contentsOf: chunkBuffer)
                chunkBuffer.removeAll(keepingCapacity: true)

                // Throttle speed if limiter active
                if let limiter = speedLimiter {
                    await limiter.throttle(bytes: Int64(bufferThreshold))
                }

                updateSpeedAndETA()
                onProgressUpdate?(item)
            }
        }

        // Write remaining bytes
        if !chunkBuffer.isEmpty {
            try fileHandle.write(contentsOf: chunkBuffer)
            chunkBuffer.removeAll()
        }

        try fileHandle.close()

        // Download complete: atomically move from .part to target destination
        let finalDestination = item.destinationFileURL
        if fileManager.fileExists(atPath: finalDestination.path) {
            try fileManager.removeItem(at: finalDestination)
        }
        try fileManager.moveItem(at: partURL, to: finalDestination)

        item.status = .completed
        item.completedAt = Date()
        item.speed = 0
        item.eta = nil
        onProgressUpdate?(item)
        onCompletion?(item)
    }

    private func updateSpeedAndETA() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSpeedCalculationTime)

        if elapsed >= 0.5 {
            let instantaneousSpeed = Double(bytesSinceLastSpeedCalculation) / elapsed
            recentSpeeds.append(instantaneousSpeed)
            if recentSpeeds.count > 5 {
                recentSpeeds.removeFirst()
            }

            let rollingAverageSpeed = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
            item.speed = rollingAverageSpeed

            if rollingAverageSpeed > 0 && item.totalBytes > item.downloadedBytes {
                let remainingBytes = item.totalBytes - item.downloadedBytes
                item.eta = Double(remainingBytes) / rollingAverageSpeed
            } else {
                item.eta = nil
            }

            lastSpeedCalculationTime = now
            bytesSinceLastSpeedCalculation = 0
        }
    }

    private func handlePauseOrCancel() {
        item.speed = 0
        item.eta = nil
        if item.status != .cancelled {
            item.status = .paused
        }
        onProgressUpdate?(item)
    }

    private func handleFailure(error: Error) {
        item.status = .failed
        item.errorMessage = error.localizedDescription
        item.speed = 0
        item.eta = nil
        onProgressUpdate?(item)
        onFailure?(item, error)
    }

    private func extractFilenameFromContentDisposition(_ header: String) -> String? {
        // e.g. attachment; filename="example.zip" or filename*=UTF-8''example.zip
        let components = header.components(separatedBy: ";")
        for comp in components {
            let trimmed = comp.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().starts(with: "filename=") {
                let val = trimmed.dropFirst("filename=".count)
                return val.trimmingCharacters(in: CharacterSet(charactersIn: "\" '"))
            }
        }
        return nil
    }
}
