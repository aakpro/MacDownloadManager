# MacDownloader 🚀
> The High-Performance, IDM-Grade Download Manager for macOS.

MacDownloader is a native macOS application engineered in Swift 6 and SwiftUI/AppKit, delivering the acceleration, queue orchestration, and automation familiar to users of Internet Download Manager (IDM) on Windows.

---

## ✨ Features

- ⚡ **Dynamic Multi-Segment Acceleration (IDM Turbo)**: Probes server capabilities (`Accept-Ranges: bytes`) and splits files into 2–8 parallel byte-range streams, downloaded concurrently and merged on the fly.
- 📊 **Real-Time Segment Visualizer**: IDM-style micro-segment progress indicators displaying per-connection chunk progress.
- 📥 **Batch Multi-Link Paste**: Ingest links separated by commas, newlines, semicolons, or mixed whitespace.
- 🎯 **Drag-and-Drop Ingestion**: Drop URLs, plain text, or `.txt` files directly onto the app window with instant drop-zone highlight.
- 🧺 **Floating Drop Target Basket**: Draggable, borderless always-on-top mini drop widget for quick link grabbing across desktop spaces.
- ⏱️ **Resumable Transfers**: Seamlessly pause and resume broken downloads using RFC 9110 HTTP Range headers without redownloading finished bytes.
- ⏰ **Automated Time-Based Scheduler**: Schedule download windows (e.g. 02:00 AM to 06:00 AM), overnight spans past midnight, and active days of the week.
- 🚦 **Bandwidth Speed Limiter & Profiles**: Prevent network saturation with token-bucket rate limits (500 KB/s, 1 MB/s, 5 MB/s, Unlimited) and scheduled throttling.
- 🖥️ **Menu Bar Status Extra (`NSStatusItem`)**: Live aggregate transfer speed in macOS status bar, active items preview, and quick Pause/Resume controls.
- 🏷️ **Dynamic Dock Tile Integration**: Live Dock badge counter for remaining active items and custom bottom progress bar overlay.
- ⚡ **macOS Power Management**: Prevents system idle sleep during active downloads via `ProcessInfo.beginActivity`; optional "Put Mac to Sleep" or "Shut Down Mac" on queue completion.
- 🌐 **Browser Extension & Native Messaging**: Manifest V3 extension for Chrome, Brave, Edge, and Firefox with download interception and context menu integration, plus `macdownloader://` URL scheme.
- 📂 **Smart File Categorization**: Automatically routes downloads into *Documents*, *Archives*, *Video*, *Audio*, *Programs*, and *General*.
- 🔢 **Batch Pattern Generator**: Queue sequential URLs with brackets, e.g. `https://example.com/file[01-20].zip`.
- 📋 **Clipboard Monitor**: Detects copied download links on macOS (`NSPasteboard`) and prompts to capture them.
- 🛡️ **Checksum Verification**: Validates SHA-256 and MD5 hashes to guarantee file integrity.
- 🔔 **macOS Notifications & Audio**: Native macOS banner alerts and completion chimes.
- 📁 **Finder Integration**: Direct "Reveal in Finder" and Trash integration (`FileManager.default.trashItem`).

---

## 🏗️ Architecture

MacDownloader is divided into clean modular layers:
- **`MacDownloaderCore`**: Headless business logic, multi-segment network engine, speed limiter, queue scheduler, time scheduler, native messaging protocol, and persistence.
- **`MacDownloaderApp`**: Native macOS SwiftUI & AppKit interface with reactive MVVM binding, menu bar extra, dock tile progress, and power assertions.
- **`MacDownloaderTests`**: 49 automated unit and integration tests including range stitching, scheduling window logic, native host protocol framing, and live streaming.
- **`Extensions/BrowserExtension`**: Manifest V3 extension bundle and automated native messaging host installer (`install_host.sh`).

For in-depth specifications and architectural diagrams, see:
- [Technical Specification](docs/SPECIFICATION.md)
- [Architecture & Design](docs/ARCHITECTURE.md)
- [IDM Feature Matrix](docs/IDM_FEATURES.md)
- [Makefile Guide](docs/MAKEFILE_GUIDE.md)
- [Phase & Branch Log](docs/PHASES.md)

---

## 🛠️ Quick Start & Makefile Usage

MacDownloader requires macOS 14.0+ and Xcode command-line tools.

### Build Release Binary
```bash
make build
```

### Run Full Test Suite
```bash
make test
```

### Run Application
```bash
make run
```

### Package into Standalone `.app` Bundle
```bash
make app
open build/MacDownloader.app
```

### Install Browser Native Messaging Host
```bash
bash Extensions/BrowserExtension/install_host.sh
```

---

## 🌿 Phase Delivery Summary

1. **Phase 1**: Core models, URL parser, multi-segment worker, speed limiter, unit tests.
2. **Phase 2**: Concurrency scheduler, auto-categorization, checksums, persistence.
3. **Phase 3**: SwiftUI main view, batch paste sheet, settings, clipboard monitor, notifications.
4. **Phase 4**: Standalone `.app` bundle, release checklist, and `v1.0.0` tag.
5. **Phase 5**: Multi-segment parallel acceleration (IDM Turbo) with chunk reassembly and UI indicators.
6. **Phase 6**: Menu Bar Extra, Dock Tile progress overlay, and sleep prevention (`PowerManager`).
7. **Phase 7**: Time-Based Queue Scheduler (`QueueTimeScheduler`, `SchedulerSheet`).
8. **Phase 8**: Browser Web Interception (`NativeHostMessage`, Manifest V3 Extension, `macdownloader://`).
9. **Phase 9**: Drag-and-Drop link ingestion & Floating Drop Target basket (`FloatingDropTargetManager`).
10. **Phase 10**: Complete test verification (49 passing tests) and release packaging.

---

## 📄 License
MIT License. Copyright © 2026 MacDownloader.
