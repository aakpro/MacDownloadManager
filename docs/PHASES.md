# Development Phases & Branch Log

This document tracks the incremental delivery of MacDownloader across isolated Git feature branches, testing milestones, and release tagging.

---

## Phase Status Summary

| Phase | Branch Name | Status | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **Phase 1** | `feat/phase-1-core-engine` | **Completed** | Models, URLParser (comma/newline/patterns), SpeedLimiter, DownloadWorker, 17 Unit Tests |
| **Phase 2** | `feat/phase-2-queue-persistence` | **Completed** | QueueScheduler, CategoryManager, ChecksumVerifier, PersistenceManager, 24 Tests |
| **Phase 3** | `feat/phase-3-macos-ui` | **In Progress** | SwiftUI UI (MainView, BatchAddSheet, Settings), ClipboardMonitor, Notifications |
| **Phase 4** | `feat/phase-4-release-packaging` | Planned | Makefile packaging (`make app`), Full Tests, Docs Finalization, Merge & Tag `v1.0.0` |

---

## Phase 1: Core Engine & Multi-Segment Downloads
- **Branch**: `feat/phase-1-core-engine`
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
- **Branch**: `feat/phase-2-queue-persistence`
- **Focus**:
  - `QueueScheduler` with concurrency cap, worker pool, priority dispatch, Pause All / Resume All.
  - `CategoryManager` routing files into Documents, Archives, Video, Audio, Programs.
  - `ChecksumVerifier` with SHA-256 and MD5 hash calculations.
  - `PersistenceManager` saving queue state to JSON and recovering in-flight tasks.
- **Verification**: Integration tests for concurrency limits, queue advancing, and persistence.

---

## Phase 3: Native macOS SwiftUI UI & System Integrations
- **Branch**: `feat/phase-3-macos-ui`
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
- **Branch**: `feat/phase-4-release-packaging`
- **Focus**:
  - Makefile target `make app` generating standalone `build/MacDownloader.app`.
  - Complete `README.md` and finalized documentation in `docs/`.
  - Merge into `main`.
  - Tag release `v1.0.0`.
  - Push branches and tag to GitHub remote.
