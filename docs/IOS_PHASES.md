# iOSDownloader: Development Phases & Roadmap

This document outlines the step-by-step engineering roadmap for developing **iOSDownloader** (MacDownloader for iOS & iPadOS), organizing the project into 10 structured, independently testable phases.

---

## Phase Status Summary

| Phase | Component / Area | Status | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Core Engine & Background Transfer | **Planned** | `BackgroundTransferManager`, `URLSessionDownloadTask`, RFC Range resume, data models |
| **Phase 2** | iOS SwiftUI UI & Adaptive Layouts | **Planned** | iPhone & iPad Navigation, Queue list, swipe actions, speed meter, status pills |
| **Phase 3** | Built-in Browser & Media Sniffer | **Planned** | `WKWebView`, media heuristic sniffer, floating action bubble, cookie preservation |
| **Phase 4** | System Share Sheet & Safari Extension | **Planned** | App Group container (`group.com.macdownloader`), Share Sheet Extension, Safari MV3 |
| **Phase 5** | Live Activities & Dynamic Island | **Planned** | `ActivityKit` attributes, Compact/Expanded Dynamic Island, Lock Screen live widget |
| **Phase 6** | Files App Integration & QuickLook | **Planned** | `UIFileSharingEnabled`, `QLPreviewController`, in-app ZIP/RAR archive unzipper |
| **Phase 7** | AVPlayer, PiP & Background Audio | **Planned** | Custom `AVPlayer`, Picture-in-Picture, Now Playing controls on Lock Screen |
| **Phase 8** | Local Wi-Fi Web Transfer | **Planned** | Embedded HTTP server, local web upload/download UI, Bonjour discovery |
| **Phase 9** | MacDownloader Sync & App Intents | **Planned** | iCloud Queue sync, Handoff, Siri / Shortcuts `AppIntents` automation |
| **Phase 10** | Hardening, Performance & TestFlight | **Planned** | Energy & memory profiling, unit/UI test suite, TestFlight build assembly |

---

## Detailed Phase Breakdown

### Phase 1: Core Engine & Background Transfer Handover
- **Objective**: Establish the core iOS download engine capable of running both in foreground and in system background.
- **Key Tasks**:
  - Implement shared domain models (`DownloadItem`, `DownloadStatus`, `DownloadCategory`).
  - Configure `URLSessionConfiguration.background(withIdentifier: "com.macdownloader.bg")`.
  - Handle `urlSessionDidFinishEvents(forBackgroundURLSession:)` and delegate completion handlers.
  - Implement byte-range resumption logic using system `resumeData`.
  - Checksum validation utility (SHA-256 / MD5).
- **Verification**: Unit tests verifying task creation, cancellation, resume data serialization, and checksum verification.

---

### Phase 2: iOS SwiftUI UI & Adaptive Navigation
- **Objective**: Create a responsive SwiftUI interface supporting iPhone (Compact) and iPad (Split View).
- **Key Tasks**:
  - `MainQueueView`: Download card list with smooth progress bar, speed badge, and micro-segment visualization.
  - Category filtering toolbar (All, Video, Audio, Archives, Documents, Programs).
  - Context menus and swipe actions: Pause, Resume, Delete, Open in Files, Share via AirDrop.
  - Batch Add URL sheet with clipboard auto-detection and pattern expansion (`[01-20]`).
  - Global bottom bar displaying active aggregate throughput.
- **Verification**: UI previews across iPhone 15/16 Pro, iPad Pro 11", and iPad Pro 13".

---

### Phase 3: Built-in Browser & Media Sniffer
- **Objective**: Allow users to browse the web and automatically detect downloadable media and files.
- **Key Tasks**:
  - Wrap `WKWebView` with URL navigation, back/forward history, tabs, and desktop site toggle.
  - Inject custom user script sniffing network requests, `<video>`, `<audio>`, and direct file download headers (`Content-Disposition: attachment`).
  - Floating action badge: animate when media is detected with file size and resolution metadata.
  - Preserve authentication cookies and custom `User-Agent` when handing over links to download engine.
- **Verification**: Test sniffing on common audio/video pages, document links, and direct file mirrors.

---

### Phase 4: System Share Sheet & Safari Web Extension
- **Objective**: Enable one-tap download ingestion from anywhere in iOS.
- **Key Tasks**:
  - Configure App Group: `group.com.macdownloader.shared`.
  - Build **Share / Action Extension**: accepts URLs or text from any app, parses links, stores into App Group database, and triggers background download.
  - Build **Safari Web Extension** (Manifest V3): adds toolbar button to Mobile Safari with link scanner and download options.
- **Verification**: Test link sharing from Safari, Chrome, YouTube, X, and Files into iOSDownloader.

---

### Phase 5: Live Activities & Dynamic Island
- **Objective**: Real-time download feedback outside the app using `ActivityKit`.
- **Key Tasks**:
  - Define `DownloadActivityAttributes` and `ContentState` (progress, speed, filename, remaining seconds).
  - **Dynamic Island Compact Leading**: Animated download arrow.
  - **Dynamic Island Compact Trailing**: Circular progress indicator & download speed.
  - **Dynamic Island Expanded**: Detailed view with full filename, progress bar, downloaded / total size, and Pause button.
  - **Lock Screen Banner**: Full-width interactive card with progress bar and controls.
- **Verification**: Simulated and on-device testing of Dynamic Island expansions and lock screen updates.

---

### Phase 6: Files App Provider, Archive Unzipper & QuickLook
- **Objective**: Provide comprehensive document management directly on iOS.
- **Key Tasks**:
  - Enable `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` in `Info.plist`.
  - Files app provider: downloads appear immediately in `Files > On My iPhone > iOSDownloader`.
  - In-app archive unzipper: decompress `.zip`, `.tar.gz`, `.rar`, `.7z` directly into subfolders.
  - QuickLook integration (`QLPreviewController`): instant preview for PDFs, images, text, and documents.
- **Verification**: Verify file accessibility from Files app, extract multi-file ZIPs, and preview PDFs.

---

### Phase 7: AVPlayer with PiP & Background Audio
- **Objective**: Deliver a media consumption experience directly inside the download manager.
- **Key Tasks**:
  - Custom video player utilizing `AVPlayer` and `AVPictureInPictureController`.
  - Background audio playback session (`AVAudioSessionCategoryPlayback`) for podcasts, music, and lectures.
  - Integrate with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` (lock screen scrub bar, play/pause).
  - Gestures: swipe left/right to scrub, double-tap to skip 10 seconds.
- **Verification**: Verify Picture-in-Picture video playback while switching apps and background audio playback with screen locked.

---

### Phase 8: Local Wi-Fi Web Transfer & Local Network Sharing
- **Objective**: Cable-free file transfer between iPhone and any Mac or PC on the local network.
- **Key Tasks**:
  - Embed lightweight HTTP/WebDAV server (e.g. via SwiftNIO or lightweight GCDWebServer alternative).
  - Display connection card with local IP and QR code (e.g. `http://192.168.1.45:8080`).
  - Web interface allowing desktop browser users to view files, download to desktop, or upload files directly onto the iPhone.
  - Bonjour service publishing (`_iosdownloader._tcp`).
- **Verification**: Connect desktop Safari to iPhone IP; perform multi-file upload and download.

---

### Phase 9: MacDownloader Continuity, iCloud Sync & Siri Shortcuts
- **Objective**: Deep integration with the existing MacDownloader desktop ecosystem.
- **Key Tasks**:
  - CloudKit / iCloud Drive queue sync: synchronized download history and bookmark queue.
  - Handoff support: start reviewing downloads on iPhone and seamlessly continue in MacDownloader on Mac.
  - `AppIntents` integration:
    - *"Hey Siri, download clipboard URL with Downloader"*
    - Shortcuts action: *"Download with iOSDownloader"* taking URL input.
- **Verification**: Trigger Shortcuts workflow with copied link; test Handoff continuity icon in macOS Dock.

---

### Phase 10: App Store Compliance, Profiling & TestFlight
- **Objective**: Production readiness, energy efficiency, and App Store submission.
- **Key Tasks**:
  - Xcode Instruments profiling: Memory graph leaks, CPU energy impact, network cache footprint.
  - Low Power Mode & Cellular data guardrails verification.
  - Ensure strict compliance with App Store Review Guidelines (2.5.4, 5.2.3).
  - Prepare App Store assets (AppIcon 1024x1024, screenshots for 6.7" and 13" iPad).
  - Assemble TestFlight release build.
- **Verification**: Zero memory leaks, graceful background termination handling, passing App Store pre-flight validation.
