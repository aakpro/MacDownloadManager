# Development Phases & Branch Log

This document tracks the incremental delivery of MacDownloader across isolated Git feature branches, testing milestones, and release tagging.

---

## Phase Status Summary

| Phase | Branch / Component | Status | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **Phase 1** | `feat/phase-1-core-engine` | **Completed** | Models, URLParser (comma/newline/patterns), SpeedLimiter, DownloadWorker, 17 Unit Tests |
| **Phase 2** | `feat/phase-2-queue-persistence` | **Completed** | QueueScheduler, CategoryManager, ChecksumVerifier, PersistenceManager, 24 Tests |
| **Phase 3** | `feat/phase-3-macos-ui` | **Completed** | SwiftUI UI (MainView, BatchAddSheet, Settings, Row), ClipboardMonitor, Notifications |
| **Phase 4** | `feat/phase-4-release-packaging` | **Completed** | Makefile packaging (`make app`), Full Tests, Docs Finalization, Merge & Tag `v1.0.0` |
| **Phase 5** | Multi-Segment Parallel Acceleration | **Completed** | IDM Turbo: HTTP Probe, dynamic range partitioning (2-8 streams), concurrent chunk streaming, reassembly, UI segment indicators |
| **Phase 6** | Menu Bar, Dock & Power Management | **Completed** | `MenuBarManager` (`NSStatusItem`), `DockTileManager` (live badge & progress overlay), `PowerManager` (sleep prevention & post-download sleep/shutdown) |
| **Phase 7** | Time-Based Queue Scheduler | **Completed** | `QueueTimeScheduler`, `ScheduleConfig` (windows, days of week, scheduled throttling, auto pause/resume), `SchedulerSheet` UI |
| **Phase 8** | Browser Web Interception | **Completed** | Chrome/Firefox/Safari Native Messaging (`NativeHostMessage`), Manifest V3 Extension (`background.js`), URL scheme (`macdownloader://`), installer script |
| **Phase 9** | Drag-and-Drop & Drop Target Widget | **Completed** | Drag-and-drop link ingestion in `MainView`, IDM-style floating drop basket (`FloatingDropTargetManager`) |
| **Phase 10** | Release Verification & Packaging | **Completed** | 49 unit and integration tests passing, standalone `MacDownloader.app` bundle assembled |

---

## Phase 1: Core Engine & Multi-Segment Downloads
- **Focus**:
  - Swift Package manifest (`Package.swift`).
  - Core domain models: `DownloadItem`, `DownloadStatus`, `DownloadSegment`, `DownloadCategory`.
  - Advanced `URLParser` supporting comma/newline/semicolon separation, pattern ranges (`[01-10]`), and extension filters.
  - Token-bucket `SpeedLimiter`.
  - Resumable `DownloadWorker` with byte-range streaming, rolling speed, and ETA calculations.
  - Full suite of unit tests.
- **Verification**: `make test` & `make build` pass.

---

## Phase 2: Queue Scheduler, Categorization & Persistence
- **Focus**:
  - `QueueScheduler` with concurrency cap, worker pool, priority dispatch, Pause All / Resume All.
  - `CategoryManager` routing files into Documents, Archives, Video, Audio, Programs.
  - `ChecksumVerifier` with SHA-256 and MD5 hash calculations.
  - `PersistenceManager` saving queue state to JSON and recovering in-flight tasks.
- **Verification**: Integration tests for concurrency limits, queue advancing, and persistence.

---

## Phase 3: Native macOS SwiftUI UI & System Integrations
- **Focus**:
  - SwiftUI root app (`MacDownloaderApp`).
  - `MainView` with category sidebar, toolbar, filter pills, and live aggregate speed meter.
  - `BatchAddSheet` with multi-link paste input, pattern tab, and live valid URL counter.
  - `DownloadRowView` with file icon, progress bar, segment indicators, speed, ETA, and actions.
  - `ClipboardMonitor` detecting copied URLs from browser.
  - System notification and audio chime dispatch.
- **Verification**: UI compiles cleanly and unit/integration tests remain 100% green.

---

## Phase 4: Release Packaging & GitHub Tagging
- **Focus**:
  - Makefile target `make app` generating standalone `build/MacDownloader.app`.
  - Complete `README.md` and finalized documentation in `docs/`.
  - Merge into `main`.
  - Tag release `v1.0.0`.
  - Push branches and tag to GitHub remote.

---

## Phase 5: Multi-Segment Parallel Acceleration (IDM Turbo Engine)
- **Focus**:
  - `probeServerCapabilities()`: Probes server via HTTP `HEAD` and range checks for `Accept-Ranges: bytes` and `Content-Length`.
  - `calculateSegments()`: Partitions large transfers into 2 to 8 non-overlapping byte ranges.
  - Concurrent `TaskGroup` range streaming with independent `.part.seg{N}` temporary files.
  - Live segment progress updates to UI and speed limiter throttling across concurrent connections.
  - Chunk reassembly: High-performance sequential assembly into `.part` and atomic promotion to final destination.
  - Resumption: Individual unfinished segments resume without redownloading completed parts.
  - Resilient fallback: Automatically falls back to single stream if server rejects partial range or returns HTTP 200.
  - UI: Micro-segment visual indicator row beneath progress bar in `DownloadRowView`.
- **Verification**: `MultiSegmentDownloadTests` (6 tests) and live chunk streaming tests passing.

---

## Phase 6: macOS Menu Bar Extra, Dock Progress & Power Management
- **Focus**:
  - `MenuBarManager`: NSStatusItem menu bar extra with live aggregate download speed and top active items preview.
  - `DockTileManager`: Dynamic Dock icon badge showing active item count and custom bottom progress bar overlay.
  - `PowerManager`: Prevents system idle sleep during active downloads via `ProcessInfo.beginActivity`.
  - Automated post-download actions: "Put Mac to Sleep" and "Shut Down Mac" on queue completion.
  - Background lifecycle: Closing main window minimizes to menu bar without terminating background queue (`applicationShouldTerminateAfterLastWindowClosed = false`).
- **Verification**: Unit and UI lifecycle verification.

---

## Phase 7: Advanced Automation, Time-Based Scheduler & Bandwidth Profiles
- **Focus**:
  - `QueueTimeScheduler`: Evaluates time-of-day windows, overnight spans past midnight (e.g. 23:00 to 06:00), and active days of week.
  - Bandwidth scheduling: Enforces scheduled speed limits during daytime work hours and unlimited off-peak transfers.
  - `SchedulerSheet`: Dedicated SwiftUI interface for configuring active hours, days, speed limits, and automation toggles.
- **Verification**: `QueueTimeSchedulerTests` (4 tests) passing.

---

## Phase 8: Browser Web Interception & Native Messaging Protocol
- **Focus**:
  - `NativeHostMessage`: 32-bit little-endian length-prefixed stdio messaging conforming to WebExtension Native Messaging standards.
  - WebExtension Manifest V3 bundle (`manifest.json`, `background.js`) intercepting `chrome.downloads.onCreated` and context menus.
  - Native Host registration script (`install_host.sh`) supporting Google Chrome, Brave, Microsoft Edge, and Mozilla Firefox.
  - macOS URL scheme: Registered `macdownloader://` for universal browser redirection.
- **Verification**: `NativeHostMessageTests` (3 tests) passing.

---

## Phase 9: Drag-and-Drop & Drop Target Widget
- **Focus**:
  - Drag-and-drop link ingestion in `MainView`: Drop URLs or raw text files onto the queue window with visual drop-zone feedback.
  - `FloatingDropTargetManager`: Floating, borderless mini drop basket panel (`NSPanel`) that floats over all desktop spaces.
- **Verification**: Interactive drop testing and UI integration.

---

## Phase 10: Complete Verification & Final Release Assembly
- **Focus**:
  - Full test suite: 49 automated unit and integration tests executing at 100% pass rate.
  - `make app`: Assembling optimized standalone `build/MacDownloader.app`.
  - Documentation and specification updates.
