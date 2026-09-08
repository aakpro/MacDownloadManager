# iOSDownloader: Technical Specification

**Product Name:** iOSDownloader (MacDownloader for iOS & iPadOS)  
**Target Platforms:** iOS 17.0+ / iPadOS 17.0+ (Optimized for iOS 18)  
**Language:** Swift 6.0  
**UI Framework:** SwiftUI & UIKit  
**Core Frameworks:** `ActivityKit`, `WebKit`, `QuickLook`, `AVKit`, `UniformTypeIdentifiers`, `BackgroundTasks`, `AppIntents`  
**Storage & Sharing:** App Group (`group.com.macdownloader.shared`), `UIFileSharingEnabled`, Files App Provider  

---

## 1. Executive Summary

**iOSDownloader** brings the speed, queue control, and automation of MacDownloader to the iPhone and iPad. While desktop operating systems allow unrestricted background daemons, mobile platforms require deep integration with iOS-specific lifecycles, background execution frameworks, and security boundaries.

iOSDownloader combines **foreground parallel multi-segment acceleration (IDM Turbo)** with seamless handover to Apple's **native Background URLSession engine**, ensuring downloads continue uninterrupted when the device is locked or when switching between apps. It features **Live Activities on the Lock Screen and Dynamic Island**, a **built-in browser with automatic media sniffing**, a **Safari Web Extension**, a universal **Share Sheet Action Extension**, an integrated **media player with Picture-in-Picture (PiP)**, and **local Wi-Fi file transfer** to Mac/PC.

---

## 2. What Features Should the iOS App Have?

An exceptional iOS download manager must cater to mobile usage patterns, touch interactions, cellular data awareness, and iOS sandbox guidelines. The feature set is categorized into five pillars:

### 2.1 Core Download Engine & Adaptive Lifecycles
- **Foreground Multi-Segment Acceleration (IDM Turbo)**:
  - When the app is in the foreground, files >= 2 MB are split into 2–6 concurrent chunk streams via `URLSession` data tasks.
  - Asynchronous chunk reassembly with progress aggregation and instantaneous speed metrics.
- **Seamless Background Transfer Handover**:
  - Automatically transitions active downloads to `URLSessionConfiguration.background(withIdentifier:)` when app enters background or screen is locked.
  - Implements `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in `AppDelegate` to capture system download completion events even when the app is suspended.
- **Smart Queue & Priority Management**:
  - Configurable concurrent download limit (1 to 5 active items).
  - Priority reordering via drag-and-drop gestures.
  - One-tap "Pause All" and "Resume All".
- **Resumable Transfers**:
  - RFC 7233 / 9110 `Range` header support with automatic recovery from interrupted connections or network switches (Wi-Fi to 5G).
  - Checksum validation (SHA-256 / MD5).

### 2.2 iOS-Native System Integrations
- **Live Activities & Dynamic Island (`ActivityKit`)**:
  - **Dynamic Island Compact View**: Real-time progress circle and download speed indicator.
  - **Dynamic Island Expanded View**: Filename, progress bar, current speed (e.g. `8.4 MB/s`), remaining time (ETA), and Pause/Cancel controls.
  - **Lock Screen Live Activity**: Prominently displays batch or single download progress, file size downloaded vs total, and action buttons.
- **Safari Web Extension & Share Sheet**:
  - **Safari Web Extension (Manifest V3)**: Detects downloadable media/links on web pages and displays a "Download with iOSDownloader" badge.
  - **Action / Share Extension**: Accessible from any app (Safari, Chrome, YouTube, Files, Telegram, X). Tapping "Share" -> "iOSDownloader" immediately enqueues the link or file.
- **Interactive Home Screen & Lock Screen Widgets**:
  - Quick-glance widgets displaying active download count, total daily/monthly bandwidth consumed, and quick-add button.
- **Shortcuts & Siri (`AppIntents`)**:
  - "Download URL" shortcut action with clipboard detection.
  - "Pause All Downloads" / "Resume All Downloads" automation triggers.

### 2.3 Built-in Web Browser with Media Sniffer
- **Embedded WebKit Browser (`WKWebView`)**:
  - Full-featured mobile browser with tab management, bookmarks, and desktop site toggle.
  - Built-in lightweight content/ad blocker to eliminate intrusive popups.
- **Automatic Media & Stream Sniffer**:
  - Automatically intercepts `.mp4`, `.mov`, `.mkv`, `.mp3`, `.flac`, `.zip`, `.pdf`, `.iso`, and common web streams.
  - Displays a non-intrusive floating action badge: *"Found 1 downloadable video (1080p, 142 MB) - Download Now?"*.
  - Supports credentialed / cookie-forwarded downloads (preserves session cookies and `User-Agent` for authenticated sites).

### 2.4 In-App File Manager & Media Center
- **Files App Integration**:
  - App directory exposed directly in the iOS **Files** app (`On My iPhone` -> `iOSDownloader`) via `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`.
- **In-App Archive Extractor**:
  - Native decompression of `.zip`, `.rar`, `.7z`, and `.tar.gz` archives without third-party utilities.
- **Media Player with Picture-in-Picture (PiP)**:
  - Custom `AVPlayer` supporting PiP video playback.
  - Background audio playback with Lock Screen now-playing controls (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`).
  - Gesture controls: double-tap to seek, swipe for volume/brightness.
- **QuickLook Document Viewer (`QLPreviewController`)**:
  - Instant preview for PDFs, Office documents, high-resolution images, and text files.

### 2.5 Local Wi-Fi Transfer & MacDownloader Ecosystem
- **Wi-Fi Web Transfer**:
  - Built-in lightweight local HTTP / WebDAV server running on local Wi-Fi.
  - Allows the user to open `http://iphone.local:8080` in Safari or Chrome on their Mac/PC to drag-and-drop files directly to/from their iPhone.
- **Continuity & Handoff with MacDownloader**:
  - Push active download queues from MacDownloader to iPhone when leaving desk.
  - Push captured links from iPhone Safari directly to MacDownloader over local network or iCloud Sync.
  - AirDrop one-tap transfer of completed files.

### 2.6 Battery, Cellular & Storage Intelligence
- **Wi-Fi Only Toggle**: Strictly prevent downloads on cellular data unless explicitly overridden per-task.
- **Low Power Mode Awareness**: Automatically reduces concurrent connections when iOS Low Power Mode is active.
- **Storage Warning & Auto-Management**: Warns when available device storage drops below 2 GB; offers one-tap cache cleanup.

---

## 3. Technical Architecture & App Extensions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            iOS Application Bundle                           │
│                                                                             │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌─────────────────┐  │
│  │   Main SwiftUI App    │  │   Action/Share Ext.   │  │   Safari Ext.   │  │
│  │  (Browser, UI, Player)│  │ (Universal Link Sniff)│  │(Web Page Sniff) │  │
│  └───────────┬───────────┘  └───────────┬───────────┘  └────────┬────────┘  │
│              │                          │                       │           │
│              ▼                          ▼                       ▼           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │         Shared App Group Container (group.com.macdownloader.shared)   │  │
│  │                                                                       │  │
│  │  • Shared Queue Database (SwiftData / JSON persistence)               │  │
│  │  • Background URLSession Download Task Handover Storage               │  │
│  │  • Common Settings (Speed limits, Wi-Fi only, categories)             │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                 ActivityKit / Live Activities & Dynamic Island        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Background Execution Protocol
1. **Foreground Mode**: Multi-segment parallel chunk streaming using `URLSessionDataTask` or custom `AsyncStream`.
2. **Background Transition Trigger**: On `sceneDidEnterBackground`, any single-stream or pending batch task is registered with `URLSessionConfiguration.background(withIdentifier: "com.macdownloader.bg")`.
3. **OS Handover**: iOS `nsurlsessiond` daemon manages network sockets.
4. **App Wakeup**: System wakes app briefly upon download completion, invoking `urlSession(_:downloadTask:didFinishDownloadingTo:)` to move files atomically to the App Group container and post a local notification.

---

## 4. App Store Guidelines & Compliance

1. **Guideline 2.5.4 (Multitasking & Background Execution)**:
   - Uses official `NSURLSession` background downloads. No disallowed background modes (e.g. silent audio loops or fake VoIP).
2. **Guideline 5.2.3 (Intellectual Property)**:
   - The app functions as a general-purpose HTTP/HTTPS download and file management utility.
   - Avoid explicit mentions or promotional materials claiming YouTube/copyrighted video ripping.
3. **Privacy Nutrition Labels**:
   - Zero user data tracking. All file storage and browser history remain strictly local on-device.
