# MacDownloader: Technical Specification

**Version:** 1.1.0 (Full IDM Feature Suite)  
**Status:** Released  
**Platform:** macOS 14.0+ (Sonoma, Sequoia)  
**Language:** Swift 6.0  
**UI Framework:** SwiftUI & AppKit  
**Engine:** Multi-Segment Parallel HTTP Range Streaming (IDM Turbo)  

---

## 1. Executive Summary

MacDownloader is a native macOS download manager engineered to bring the acceleration, queue management, and deep automation of Internet Download Manager (IDM) to macOS. It provides multi-link paste parsing, dynamic multi-part range downloading (up to 8 parallel streams), bandwidth throttling, smart file categorization, clipboard monitoring, time-based queue scheduling, menu bar background monitoring, dock progress integration, system sleep prevention, and browser extension web interception.

---

## 2. Functional Requirements

### 2.1 Batch Link Input & Ingestion
- **Delimiters Supported**: Comma (`,`), Semicolon (`;`), Newline (`\n`, `\r\n`), and Mixed Whitespace.
- **Pattern Expansion**: Syntax like `https://example.com/item[01-20].zip` generates sequential download tasks with zero-padded or integer sequences.
- **URL Filtering & Sanitization**: Validates HTTP/HTTPS schemes, normalizes query parameters, and supports extension filtering (`.mp4`, `.srt`, etc.).
- **Drag-and-Drop Ingestion**: Drop URLs, plain text, or `.txt` files directly onto `MainView` with visual drop-zone feedback.
- **Floating Drop Target**: Always-on-top draggable mini basket window for quick link dropping across workspaces.

### 2.2 Download Engine & Protocols (IDM Turbo)
- **Multi-Segment Parallel Acceleration**:
  - Probe request checks `Accept-Ranges: bytes` and `Content-Length`.
  - Splits files >= 2 MB into 2 to 8 non-overlapping byte ranges downloaded in parallel via concurrent `TaskGroup` streams.
  - Asynchronously reassembles temporary segment files (`.part.seg{N}`) with zero disk thrashing.
  - Micro-segment visual progress indicators render live chunk download progress in `DownloadRowView`.
- **Resumable Transfers**:
  - RFC 9110 / RFC 7233 byte-range resumption.
  - Resumes individual unfinished segments without redownloading completed parts.
  - Automatic fallback to single-stream sequential download if server rejects partial range or returns HTTP 200.
- **Bandwidth Throttling (Speed Limiter)**:
  - Token-bucket algorithm enforcing bandwidth limits (e.g. 500 KB/s, 1 MB/s, 5 MB/s, Unlimited).
- **Error Recovery & Backoff**:
  - Automatically recovers from HTTP 416 (Range Not Satisfiable) by clearing invalid offsets and retrying fresh.
  - Automatic 302 redirection handling preserving headers and `Referer: scheme://host/`.

### 2.3 Queue & Automation Management
- **State Machine**: `[QUEUED] -> [CONNECTING] -> [DOWNLOADING] -> [COMPLETED] / [PAUSED] / [FAILED] / [CANCELLED]`.
- **Worker Pool**: Configurable concurrency ceiling (`maxConcurrentDownloads`: default 3, range 1–10).
- **Time-Based Queue Scheduler**:
  - Define automated download windows (e.g. 02:00 AM to 06:00 AM), overnight spans, and active days of week.
  - Scheduled speed limit profiles (throttle during work hours, full speed overnight).
  - Auto-start when schedule window opens; auto-pause when schedule window closes.

### 2.4 macOS System Integrations
- **Menu Bar Status Item (`NSStatusItem`)**:
  - Displays live aggregate transfer speed in system menu bar.
  - Menu lists top active downloads, quick Pause All, Resume All, Add URLs, and Open App.
- **Dock Tile Integration (`NSApp.dockTile`)**:
  - Dynamic badge counter displaying active download count.
  - Custom progress bar drawn directly onto the Dock tile icon.
- **System Power Management**:
  - Prevents macOS idle sleep during active downloads via `ProcessInfo.beginActivity`.
  - Post-queue completion triggers: "Put Mac to Sleep" or "Shut Down Mac".
  - Retains background menu bar helper when main window closes (`applicationShouldTerminateAfterLastWindowClosed = false`).

### 2.5 Browser Integration (Web Interception)
- **Native Messaging Protocol**:
  - Stdio-based 32-bit little-endian length-prefixed JSON protocol compatible with Chrome, Brave, Edge, and Firefox.
  - Installer script (`install_host.sh`) registers native messaging manifests.
- **Browser Extension (Manifest V3)**:
  - Intercepts browser download creation events (`chrome.downloads.onCreated`).
  - Context menu items: "Download with MacDownloader" and "Download Page with MacDownloader".
- **URL Scheme**:
  - Registered `macdownloader://download?url=...` for universal redirection.

---

## 3. Architecture & Data Structures

```
[ SwiftUI App View ]  <-->  [ AppViewModel (ObservableObject) ]
      |                             |
[ MainView ]                 [ QueueScheduler ]  <--->  [ QueueTimeScheduler ]
      |                         /          \
[ MenuBarManager ]   [ DownloadWorker ]  [ PersistenceManager ]
      |                     |         \
[ DockTileManager ]  [ SpeedLimiter ]  [ URLSession ]
      |
[ PowerManager ]
```

---

## 4. Changelog & Phase History
- **v1.0.0**: Core engine, queue scheduler, categorization, persistence, and initial SwiftUI UI.
- **v1.0.1**: Query parameter filename parsing, Referer/redirect headers, HTTP 416 recovery, deletion/Trash integration.
- **v1.1.0 (Phases 5–10 Complete)**:
  - Phase 5: Multi-segment parallel acceleration (IDM Turbo).
  - Phase 6: Menu Bar Extra (`NSStatusItem`), Dock Tile progress, sleep prevention (`PowerManager`).
  - Phase 7: Time-Based Queue Scheduler (`QueueTimeScheduler`, `SchedulerSheet`).
  - Phase 8: Browser Web Interception (`NativeHostMessage`, Manifest V3 Extension, `install_host.sh`).
  - Phase 9: Drag-and-Drop link ingestion & Floating Drop Target basket (`FloatingDropTargetManager`).
  - Phase 10: 49 unit and integration tests passing, release `.app` package assembled.
