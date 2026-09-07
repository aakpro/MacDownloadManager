import Foundation

/// Core network worker responsible for executing a single download item using high-performance chunked streams and byte ranges.
public actor DownloadWorker {
    public let itemID: UUID
    public private(set) var item: DownloadItem

    private var activeTask: Task<Void, Error>?
    private var activeStreamSession: WorkerStreamSession?
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
        urlSession: URLSession? = nil,
        speedLimiter: SpeedLimiter? = nil
    ) {
        self.itemID = item.id
        self.item = item
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
        activeStreamSession?.cancel()
        activeStreamSession = nil
        activeTask?.cancel()
        activeTask = nil
        onProgressUpdate?(item)
    }

    /// Cancels download and cleans up partial files.
    public func cancel() {
        item.status = .cancelled
        item.speed = 0
        item.eta = nil
        activeStreamSession?.cancel()
        activeStreamSession = nil
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

        var currentPartURL = item.partFileURL
        var existingBytes: Int64 = 0
        if fileManager.fileExists(atPath: currentPartURL.path) {
            if let attrs = try? fileManager.attributesOfItem(atPath: currentPartURL.path),
               let size = attrs[.size] as? Int64 {
                existingBytes = size
            }
        }

        var request = URLRequest(url: item.url)
        request.timeoutInterval = 45

        // Standard browser headers
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        // Crucial for sites like git.ir that reject requests without Referer
        if let scheme = item.url.scheme, let host = item.url.host {
            request.setValue("\(scheme)://\(host)/", forHTTPHeaderField: "Referer")
        }

        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
        }

        let streamer = WorkerStreamSession()
        self.activeStreamSession = streamer

        var (httpResponse, stream) = try await streamer.start(request: request)

        // Handle 416 Range Not Satisfiable: partial file offset invalid, retry fresh from 0
        if httpResponse.statusCode == 416 && existingBytes > 0 {
            try? fileManager.removeItem(at: currentPartURL)
            existingBytes = 0
            request.setValue(nil, forHTTPHeaderField: "Range")
            let retryStreamer = WorkerStreamSession()
            self.activeStreamSession = retryStreamer
            let retried = try await retryStreamer.start(request: request)
            httpResponse = retried.0
            stream = retried.1
        }

        // Determine resume capability & Content-Length
        let isPartial = httpResponse.statusCode == 206
        let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
        item.supportsRanges = isPartial || acceptRanges

        // Refine filename from server response (Content-Disposition or final redirect target URL)
        var refinedName: String?
        if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
           let parsed = DownloadItem.extractFilenameFromContentDisposition(contentDisposition) {
            refinedName = parsed
        } else if let finalURL = httpResponse.url {
            let extracted = DownloadItem.extractFilename(from: finalURL)
            if !extracted.starts(with: "download_") && extracted != (item.url.lastPathComponent) {
                refinedName = extracted
            }
        }

        if let newName = refinedName, !newName.isEmpty && newName != item.filename {
            let uniqueNewName = CategoryManager.resolveUniqueFilename(in: item.destinationFolder, originalFilename: newName)
            let oldPartURL = currentPartURL
            item.filename = uniqueNewName
            item.category = DownloadCategory.detect(from: uniqueNewName)
            currentPartURL = item.partFileURL

            if fileManager.fileExists(atPath: oldPartURL.path) && oldPartURL != currentPartURL {
                try? fileManager.moveItem(at: oldPartURL, to: currentPartURL)
            }
        }

        // Determine total content length
        if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
           let totalStr = contentRange.components(separatedBy: "/").last?.trimmingCharacters(in: .whitespaces),
           let total = Int64(totalStr), total > 0 {
            item.totalBytes = total
        } else {
            let responseLength = httpResponse.expectedContentLength
            if responseLength > 0 {
                item.totalBytes = isPartial ? (existingBytes + responseLength) : responseLength
            }
        }

        // Initialize file handle
        let fileHandle: FileHandle
        if isPartial && existingBytes > 0 {
            item.downloadedBytes = existingBytes
            fileHandle = try FileHandle(forWritingTo: currentPartURL)
            try fileHandle.seekToEnd()
        } else {
            // New download or server ignored Range request
            item.downloadedBytes = 0
            fileManager.createFile(atPath: currentPartURL.path, contents: nil)
            fileHandle = try FileHandle(forWritingTo: currentPartURL)
        }

        item.status = .downloading
        lastSpeedCalculationTime = Date()
        bytesSinceLastSpeedCalculation = 0
        onProgressUpdate?(item)

        // Stream high-performance data chunks
        do {
            for try await chunk in stream {
                try Task.checkCancellation()

                try fileHandle.write(contentsOf: chunk)
                item.downloadedBytes += Int64(chunk.count)
                bytesSinceLastSpeedCalculation += Int64(chunk.count)

                // Throttle speed if limiter active
                if let limiter = speedLimiter {
                    await limiter.throttle(bytes: Int64(chunk.count))
                }

                updateSpeedAndETA()
                onProgressUpdate?(item)
            }

            try fileHandle.synchronize()
            try fileHandle.close()
        } catch {
            try? fileHandle.close()
            throw error
        }

        // Verify task was not cancelled while stream was wrapping up
        try Task.checkCancellation()

        // Verify download wasn't truncated prematurely
        if item.totalBytes > 0 && item.downloadedBytes < item.totalBytes {
            throw URLError(.networkConnectionLost)
        }

        self.activeStreamSession = nil

        // Download complete: atomically move from .part to target destination
        let finalDestination = item.destinationFileURL
        if fileManager.fileExists(atPath: finalDestination.path) {
            try fileManager.removeItem(at: finalDestination)
        }
        try fileManager.moveItem(at: currentPartURL, to: finalDestination)

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
        activeStreamSession = nil
        onProgressUpdate?(item)
    }

    private func handleFailure(error: Error) {
        item.status = .failed
        item.errorMessage = error.localizedDescription
        item.speed = 0
        item.eta = nil
        activeStreamSession = nil
        onProgressUpdate?(item)
        onFailure?(item, error)
    }
}

// MARK: - Dedicated Chunk Streaming Network Session

private final class WorkerStreamSession: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var responseContinuation: CheckedContinuation<HTTPURLResponse, Error>?
    private var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?

    override init() {
        super.init()
    }

    func start(request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, Error>) {
        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        self.streamContinuation = continuation

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 86400
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            "Accept": "*/*"
        ]

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        let task = session.dataTask(with: request)
        self.dataTask = task

        let httpResponse = try await withCheckedThrowingContinuation { cont in
            self.responseContinuation = cont
            task.resume()
        }

        return (httpResponse, stream)
    }

    func cancel() {
        dataTask?.cancel()
        streamContinuation?.finish(throwing: CancellationError())
        session?.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirected = newRequest
        // Preserve User-Agent and Referer headers on redirection
        if redirected.value(forHTTPHeaderField: "User-Agent") == nil,
           let originalUA = task.originalRequest?.value(forHTTPHeaderField: "User-Agent") {
            redirected.setValue(originalUA, forHTTPHeaderField: "User-Agent")
        }
        if redirected.value(forHTTPHeaderField: "Referer") == nil,
           let originalReferer = task.originalRequest?.value(forHTTPHeaderField: "Referer") {
            redirected.setValue(originalReferer, forHTTPHeaderField: "Referer")
        }
        completionHandler(redirected)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            responseContinuation?.resume(throwing: URLError(.badServerResponse))
            responseContinuation = nil
            completionHandler(.cancel)
            return
        }

        // 200...299 is success. Allow 416 through so caller can handle Range retries.
        if (200...299).contains(http.statusCode) || http.statusCode == 416 {
            responseContinuation?.resume(returning: http)
            responseContinuation = nil
            completionHandler(http.statusCode == 416 ? .cancel : .allow)
            return
        }

        let error = NSError(
            domain: "MacDownloaderHTTPError",
            code: http.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "HTTP Server returned status code \(http.statusCode)"]
        )
        responseContinuation?.resume(throwing: error)
        responseContinuation = nil
        completionHandler(.cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        streamContinuation?.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as? URLError)?.code == .cancelled {
                streamContinuation?.finish(throwing: CancellationError())
            } else {
                if let cont = responseContinuation {
                    responseContinuation = nil
                    cont.resume(throwing: error)
                }
                streamContinuation?.finish(throwing: error)
            }
        } else {
            if let cont = responseContinuation {
                responseContinuation = nil
                cont.resume(throwing: URLError(.cannotParseResponse))
            }
            streamContinuation?.finish()
        }
        session.finishTasksAndInvalidate()
    }
}
