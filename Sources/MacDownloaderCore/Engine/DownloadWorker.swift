import Foundation

/// Range error indicating server does not support byte ranges for segmentation.
public struct RangeNotSupportedError: Error, LocalizedError, Sendable {
    public var errorDescription: String? {
        return "Server does not support partial range requests."
    }
}

/// Core network worker responsible for executing a single download item using
/// high-performance chunked streams, dynamic multi-segment parallel acceleration (IDM Turbo),
/// and resumable byte ranges.
public actor DownloadWorker {
    public let itemID: UUID
    public private(set) var item: DownloadItem

    private var activeTask: Task<Void, Error>?
    private var activeStreamSession: WorkerStreamSession?
    private var activeSegmentSessions: [Int: WorkerStreamSession] = [:]
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
        for (_, session) in activeSegmentSessions {
            session.cancel()
        }
        activeSegmentSessions.removeAll()
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
        for (_, session) in activeSegmentSessions {
            session.cancel()
        }
        activeSegmentSessions.removeAll()
        activeTask?.cancel()
        activeTask = nil

        // Clean up partial file and segment files
        try? FileManager.default.removeItem(at: item.partFileURL)
        for segment in item.segments {
            try? FileManager.default.removeItem(at: item.segmentFileURL(for: segment))
        }
        onProgressUpdate?(item)
    }

    // MARK: - Internal Download Execution

    private func executeDownload() async throws {
        let fileManager = FileManager.default

        // Ensure destination directory exists
        try fileManager.createDirectory(at: item.destinationFolder, withIntermediateDirectories: true)

        // If item already has multiple segments configured from previous session, resume multi-segment directly
        if item.segments.count > 1 && item.totalBytes > 0 {
            do {
                try await executeMultiSegmentDownload(totalBytes: item.totalBytes)
                return
            } catch is RangeNotSupportedError {
                // Fall back to single-stream below
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw error
            }
        }

        // Probe server capabilities if multi-segment is requested
        if item.maxSegments > 1 {
            if let capabilities = await probeServerCapabilities(),
               capabilities.supportsRanges,
               capabilities.totalBytes >= 2_097_152 { // Minimum 2MB for multi-segment acceleration
                do {
                    try await executeMultiSegmentDownload(
                        totalBytes: capabilities.totalBytes,
                        initialResponse: capabilities.response
                    )
                    return
                } catch is RangeNotSupportedError {
                    // Server declared ranges but rejected partial range, fall back to single stream
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    throw error
                }
            }
        }

        // Fallback or default: single-stream sequential download
        try await executeSingleStreamDownload()
    }

    // MARK: - Multi-Segment Accelerated Download (IDM Turbo)

    private struct ServerCapabilities {
        let supportsRanges: Bool
        let totalBytes: Int64
        let response: HTTPURLResponse
    }

    private func probeServerCapabilities() async -> ServerCapabilities? {
        var headRequest = makeStandardRequest(url: item.url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 15

        let streamer = WorkerStreamSession()
        do {
            let (httpResponse, _) = try await streamer.start(request: headRequest)
            streamer.cancel()

            guard (200...299).contains(httpResponse.statusCode) else { return nil }

            let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
            let total = httpResponse.expectedContentLength
            guard total > 0 else { return nil }

            return ServerCapabilities(
                supportsRanges: acceptRanges,
                totalBytes: total,
                response: httpResponse
            )
        } catch {
            streamer.cancel()
            return nil
        }
    }

    private func executeMultiSegmentDownload(totalBytes: Int64, initialResponse: HTTPURLResponse? = nil) async throws {
        let fileManager = FileManager.default

        if let response = initialResponse {
            applyFilenameRefinement(from: response)
        }

        let targetSegmentCount = min(max(item.maxSegments, 2), 8)
        if item.segments.isEmpty || item.segments.count != targetSegmentCount {
            item.segments = DownloadSegment.calculateSegments(
                totalBytes: totalBytes,
                segmentCount: targetSegmentCount,
                filename: item.filename
            )
        }

        // Inspect existing segment part files on disk to support resuming
        for i in 0..<item.segments.count {
            let segURL = item.segmentFileURL(for: item.segments[i])
            if fileManager.fileExists(atPath: segURL.path),
               let attrs = try? fileManager.attributesOfItem(atPath: segURL.path),
               let size = attrs[.size] as? Int64 {
                if size >= item.segments[i].totalBytes {
                    item.segments[i].downloadedBytes = item.segments[i].totalBytes
                    item.segments[i].isCompleted = true
                } else {
                    item.segments[i].downloadedBytes = size
                    item.segments[i].isCompleted = false
                }
            } else {
                fileManager.createFile(atPath: segURL.path, contents: nil)
                item.segments[i].downloadedBytes = 0
                item.segments[i].isCompleted = false
            }
        }

        item.totalBytes = totalBytes
        item.downloadedBytes = item.segments.reduce(0) { $0 + $1.downloadedBytes }
        item.supportsRanges = true
        item.status = .downloading
        lastSpeedCalculationTime = Date()
        bytesSinceLastSpeedCalculation = 0
        onProgressUpdate?(item)

        // Concurrently stream unfinished segments
        try await withThrowingTaskGroup(of: Void.self) { group in
            for segment in self.item.segments where !segment.isCompleted {
                let segID = segment.id
                let startByte = segment.startByte + segment.downloadedBytes
                let endByte = segment.endByte
                let segURL = self.item.segmentFileURL(for: segment)

                guard startByte <= endByte else {
                    self.markSegmentCompleted(segmentID: segID)
                    continue
                }

                group.addTask {
                    try await self.downloadSegment(
                        segmentID: segID,
                        startByte: startByte,
                        endByte: endByte,
                        fileURL: segURL
                    )
                }
            }

            try await group.waitForAll()
        }

        try Task.checkCancellation()

        // Verify all segments completed
        guard item.segments.allSatisfy({ $0.isCompleted }) else {
            throw URLError(.networkConnectionLost)
        }

        // Reassemble segments sequentially into final part file
        let finalPartURL = item.partFileURL
        if fileManager.fileExists(atPath: finalPartURL.path) {
            try? fileManager.removeItem(at: finalPartURL)
        }
        fileManager.createFile(atPath: finalPartURL.path, contents: nil)
        let assemblyHandle = try FileHandle(forWritingTo: finalPartURL)

        for segment in item.segments {
            let segURL = item.segmentFileURL(for: segment)
            let segReadHandle = try FileHandle(forReadingFrom: segURL)
            while let chunk = try segReadHandle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                try assemblyHandle.write(contentsOf: chunk)
            }
            try segReadHandle.close()
            try? fileManager.removeItem(at: segURL)
        }
        try assemblyHandle.synchronize()
        try assemblyHandle.close()

        // Atomically move from .part to destination
        let finalDestination = item.destinationFileURL
        if fileManager.fileExists(atPath: finalDestination.path) {
            try fileManager.removeItem(at: finalDestination)
        }
        try fileManager.moveItem(at: finalPartURL, to: finalDestination)

        item.status = .completed
        item.completedAt = Date()
        item.speed = 0
        item.eta = nil
        onProgressUpdate?(item)
        onCompletion?(item)
    }

    private func downloadSegment(
        segmentID: Int,
        startByte: Int64,
        endByte: Int64,
        fileURL: URL
    ) async throws {
        var request = makeStandardRequest(url: item.url)
        request.setValue("bytes=\(startByte)-\(endByte)", forHTTPHeaderField: "Range")

        let streamer = WorkerStreamSession()
        self.activeSegmentSessions[segmentID] = streamer

        let (httpResponse, stream): (HTTPURLResponse, AsyncThrowingStream<Data, Error>)
        do {
            (httpResponse, stream) = try await streamer.start(request: request)
        } catch {
            self.activeSegmentSessions.removeValue(forKey: segmentID)
            throw error
        }

        // Must receive 206 Partial Content
        if httpResponse.statusCode != 206 {
            self.activeSegmentSessions.removeValue(forKey: segmentID)
            streamer.cancel()
            throw RangeNotSupportedError()
        }

        let fileHandle = try FileHandle(forWritingTo: fileURL)
        try fileHandle.seekToEnd()

        do {
            for try await chunk in stream {
                try Task.checkCancellation()

                try fileHandle.write(contentsOf: chunk)
                self.recordSegmentProgress(segmentID: segmentID, byteCount: chunk.count)

                if let limiter = self.speedLimiter {
                    await limiter.throttle(bytes: Int64(chunk.count))
                }
            }

            try fileHandle.synchronize()
            try fileHandle.close()
        } catch {
            try? fileHandle.close()
            self.activeSegmentSessions.removeValue(forKey: segmentID)
            throw error
        }

        self.activeSegmentSessions.removeValue(forKey: segmentID)
        self.markSegmentCompleted(segmentID: segmentID)
    }

    private func recordSegmentProgress(segmentID: Int, byteCount: Int) {
        guard let idx = item.segments.firstIndex(where: { $0.id == segmentID }) else { return }
        item.segments[idx].downloadedBytes += Int64(byteCount)
        if item.segments[idx].downloadedBytes >= item.segments[idx].totalBytes {
            item.segments[idx].isCompleted = true
        }
        item.downloadedBytes += Int64(byteCount)
        bytesSinceLastSpeedCalculation += Int64(byteCount)
        updateSpeedAndETA()
        onProgressUpdate?(item)
    }

    private func markSegmentCompleted(segmentID: Int) {
        guard let idx = item.segments.firstIndex(where: { $0.id == segmentID }) else { return }
        item.segments[idx].isCompleted = true
        item.segments[idx].downloadedBytes = item.segments[idx].totalBytes
        onProgressUpdate?(item)
    }

    // MARK: - Single-Stream Sequential Download

    private func executeSingleStreamDownload() async throws {
        let fileManager = FileManager.default
        var currentPartURL = item.partFileURL
        var existingBytes: Int64 = 0

        if fileManager.fileExists(atPath: currentPartURL.path) {
            if let attrs = try? fileManager.attributesOfItem(atPath: currentPartURL.path),
               let size = attrs[.size] as? Int64 {
                existingBytes = size
            }
        }

        var request = makeStandardRequest(url: item.url)
        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
        }

        let streamer = WorkerStreamSession()
        self.activeStreamSession = streamer

        var (httpResponse, stream) = try await streamer.start(request: request)

        // Handle 416 Range Not Satisfiable: retry fresh from 0
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

        let isPartial = httpResponse.statusCode == 206
        let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
        item.supportsRanges = isPartial || acceptRanges

        applyFilenameRefinement(from: httpResponse)
        currentPartURL = item.partFileURL

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

        let fileHandle: FileHandle
        if isPartial && existingBytes > 0 {
            item.downloadedBytes = existingBytes
            fileHandle = try FileHandle(forWritingTo: currentPartURL)
            try fileHandle.seekToEnd()
        } else {
            item.downloadedBytes = 0
            fileManager.createFile(atPath: currentPartURL.path, contents: nil)
            fileHandle = try FileHandle(forWritingTo: currentPartURL)
        }

        item.status = .downloading
        lastSpeedCalculationTime = Date()
        bytesSinceLastSpeedCalculation = 0
        onProgressUpdate?(item)

        do {
            for try await chunk in stream {
                try Task.checkCancellation()

                try fileHandle.write(contentsOf: chunk)
                item.downloadedBytes += Int64(chunk.count)
                bytesSinceLastSpeedCalculation += Int64(chunk.count)

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

        try Task.checkCancellation()

        if item.totalBytes > 0 && item.downloadedBytes < item.totalBytes {
            throw URLError(.networkConnectionLost)
        }

        self.activeStreamSession = nil

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

    // MARK: - Helpers

    private func makeStandardRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        if let scheme = url.scheme, let host = url.host {
            request.setValue("\(scheme)://\(host)/", forHTTPHeaderField: "Referer")
        }
        return request
    }

    private func applyFilenameRefinement(from httpResponse: HTTPURLResponse) {
        let fileManager = FileManager.default
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
            let oldPartURL = item.partFileURL
            item.filename = uniqueNewName
            item.category = DownloadCategory.detect(from: uniqueNewName)

            if fileManager.fileExists(atPath: oldPartURL.path) && oldPartURL != item.partFileURL {
                try? fileManager.moveItem(at: oldPartURL, to: item.partFileURL)
            }
        }
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
        activeStreamSession?.cancel()
        activeStreamSession = nil
        for (_, session) in activeSegmentSessions {
            session.cancel()
        }
        activeSegmentSessions.removeAll()
        onProgressUpdate?(item)
    }

    private func handleFailure(error: Error) {
        item.status = .failed
        item.errorMessage = error.localizedDescription
        item.speed = 0
        item.eta = nil
        activeStreamSession?.cancel()
        activeStreamSession = nil
        for (_, session) in activeSegmentSessions {
            session.cancel()
        }
        activeSegmentSessions.removeAll()
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
