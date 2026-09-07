# MacDownloader: Technical Specification

**Version:** 1.0.0 (Release)  
**Status:** Released  
**Platform:** macOS 14.0+ (Sonoma, Sequoia)  
**Language:** Swift 6.0  
**UI Framework:** SwiftUI  
**Engine:** URLSession with Resumable Byte-Range Streaming  

---

## 1. Executive Summary

MacDownloader is a native macOS download manager engineered to bring the acceleration, queue management, and deep automation of Internet Download Manager (IDM) to macOS. It provides multi-link paste parsing (comma, newline, or whitespace separated), dynamic multi-part range downloading, bandwidth throttling, smart file categorization, clipboard monitoring, and automatic queue recovery.

---

## 2. Functional Requirements

### 2.1 Batch Link Input & Ingestion
- **Delimiters Supported**: Comma (`,`), Semicolon (`;`), Newline (`\n`, `\r\n`), and Mixed Whitespace.
- **Pattern Expansion**: Syntax like `https://example.com/item[01-20].zip` generates 20 sequential download tasks with zero-padded or integer sequences.
- **URL Filtering & Sanitization**:
  - Validates schemes: `http://` and `https://`.
  - Normalizes percent-encoding.
  - Strips accidental surrounding quotes and trailing punctuation.
  - Extension filter option (e.g. paste a raw web page text and extract only `.mp4` or `.pdf` links).
- **Duplicate Prevention**: Ignores or flags URLs already active in the queue.

### 2.2 Download Engine & Protocols
- **Resumable Transfers**:
  - Implements HTTP `Range: bytes={offset}-` headers as per RFC 9110 / RFC 7233.
  - Checks server response: HTTP `206 Partial Content` (resumable) vs HTTP `200 OK` (non-resumable full stream).
- **Dynamic Multi-Segment Downloading (IDM Turbo)**:
  - When Content-Length is provided and `Accept-Ranges: bytes` is supported, splits the target file into $N$ segments (default: 4, configurable 1-8).
  - Each segment downloads concurrently to an independent byte-range temporary file.
  - On segment completion, parts are merged sequentially into the final file without disk thrashing.
- **Bandwidth Throttling (Speed Limiter)**:
  - Token-bucket algorithm enforcing global or per-download speed limits (e.g., 250 KB/s, 1 MB/s, 5 MB/s, Unlimited).
- **Error Recovery & Backoff**:
  - Automatic retry for transient errors (connection timeouts, 503 Service Unavailable, dropped packets).
  - Exponential backoff: retry after 2s, 4s, 8s up to 3 attempts before flagging as `failed`.

### 2.3 Queue & Concurrency Management
- **State Machine**:
  ```text
  [QUEUED] ---> [CONNECTING] ---> [DOWNLOADING] ---> [COMPLETED]
     |                 |                |
     |                 v                v
     +----------> [CANCELLED]       [PAUSED] <---> [DOWNLOADING]
                                        |
                                        v
                                     [FAILED] ---> [RETRYING]
  ```
- **Worker Pool**:
  - Configurable concurrency ceiling (`maxConcurrentDownloads`: default 3, range 1–10).
  - Queue prioritization (High, Normal, Low).
  - Automatic dispatch: When a worker finishes or pauses, the next queued item auto-starts.
- **Global Actions**:
  - Pause All, Resume All, Cancel All, Clear Completed, Clear Failed.

### 2.4 Smart Categorization & Organization
- Files are automatically routed based on MIME type or file extension:
  - **Documents**: `.pdf`, `.docx`, `.doc`, `.txt`, `.epub`, `.xlsx`, `.pptx`, `.md` -> `~/Downloads/Documents/`
  - **Archives**: `.zip`, `.rar`, `.7z`, `.tar`, `.gz`, `.bz2`, `.iso`, `.dmg` -> `~/Downloads/Archives/`
  - **Video**: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.flv` -> `~/Downloads/Video/`
  - **Audio**: `.mp3`, `.flac`, `.wav`, `.aac`, `.m4a`, `.ogg` -> `~/Downloads/Audio/`
  - **Programs**: `.dmg`, `.pkg`, `.app`, `.bin` -> `~/Downloads/Programs/`
  - **General**: Fallback directory -> `~/Downloads/General/`
- User can toggle auto-categorization or customize target folders.

### 2.5 Persistence & Fault Tolerance
- Queue state, segment progress, and file paths are continuously written to `~/Library/Application Support/MacDownloader/queue.json`.
- In-flight files use `.part` extensions until verified and finalized.
- Collision avoidance: If `presentation.pdf` already exists at destination, automatically saves as `presentation (1).pdf`.

### 2.6 macOS System Integration
- Native UserNotifications on completion or failure.
- Classic audio completion chimes (customizable).
- Reveal in Finder (`NSWorkspace.shared.activateFileViewerSelecting`).
- Background clipboard monitoring (`NSPasteboard`).

---

## 3. Architecture & Data Structures

```
[ SwiftUI App View ]  <-->  [ AppViewModel (ObservableObject) ]
                                    |
                            [ QueueScheduler ]
                               /          \
            [ DownloadWorker (1..N) ]    [ PersistenceManager ]
                  |            |                   |
            [ SpeedLimiter ] [ URLSession ]  [ CategoryManager ]
```

---

## 4. Security & Permissions
- App Sandbox entitlements:
  - `com.apple.security.network.client`: required for outgoing HTTP/HTTPS connections.
  - `com.apple.security.files.user-selected.read-write`: required for user destination directory selection.
  - `com.apple.security.files.downloads.read-write`: required for writing to `~/Downloads`.

---

## 5. Changelog & Phase History
- **v1.0.0-phase1**: Core engine, models, multi-segment worker, and URL parser.
- **v1.0.0-phase2**: Queue manager, persistence, checksums, and categorization.
- **v1.0.0-phase3**: SwiftUI interface, clipboard monitor, and notifications.
- **v1.0.0-phase4**: Makefile release packaging and distribution bundle.
