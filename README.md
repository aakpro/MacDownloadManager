# MacDownloader 🚀
> The High-Performance, IDM-Grade Download Manager for macOS.

MacDownloader is a native macOS application engineered in Swift and SwiftUI, delivering the acceleration, queue orchestration, and automation familiar to users of Internet Download Manager (IDM) on Windows.

---

## ✨ Features

- 📥 **Batch Multi-Link Paste**: Ingest links separated by commas, newlines, semicolons, or mixed whitespace.
- ⚡ **Dynamic Multi-Segment Acceleration**: Splits files into parallel byte-range streams (`Range: bytes=X-Y`) to maximize bandwidth.
- ⏱️ **Resumable Downloads**: Seamlessly pause and resume broken downloads using RFC 9110 HTTP Range requests.
- 🚦 **Bandwidth Speed Limiter**: Prevent network saturation with customizable rate limits (e.g. 500 KB/s, 2 MB/s, Unlimited).
- 📂 **Smart File Categorization**: Automatically routes downloads into *Documents*, *Archives*, *Video*, *Audio*, *Programs*, and *General*.
- 🔢 **Batch Pattern Generator**: Queue sequential URLs with brackets, e.g. `https://example.com/file[01-20].zip`.
- 📋 **Clipboard Monitor**: Detects copied download links on macOS (`NSPasteboard`) and prompts to capture them.
- 🛡️ **Checksum Verification**: Validates SHA-256 and MD5 hashes to guarantee file integrity.
- 🔔 **macOS Notifications & Audio**: Native macOS banner alerts and completion chimes.
- 📁 **Finder Integration**: Direct "Reveal in Finder" action for downloaded items.

---

## 🏗️ Architecture

MacDownloader is divided into clean modular layers:
- **`MacDownloaderCore`**: Headless business logic, multi-segment network engine, speed limiter, queue scheduler, and persistence.
- **`MacDownloaderApp`**: Native macOS SwiftUI interface with reactive MVVM binding.
- **`MacDownloaderTests`**: Multi-tiered test suite including unit tests, integration tests, and simulated HTTP range tests.

For in-depth specifications and architectural diagrams, see:
- [Technical Specification](docs/SPECIFICATION.md)
- [Architecture & Design](docs/ARCHITECTURE.md)
- [IDM Feature Matrix](docs/IDM_FEATURES.md)
- [Makefile Guide](docs/MAKEFILE_GUIDE.md)
- [Phase & Branch Log](docs/PHASES.md)

---

## 🛠️ Quick Start & Makefile Usage

MacDownloader requires macOS 14.0+ and Xcode command-line tools.

### Build
```bash
make build
```

### Run Tests
```bash
make test
```

### Run Application
```bash
make run
```

### Package into `.app` Bundle
```bash
make app
open build/MacDownloader.app
```

---

## 🌿 Multi-Phase Git Workflow

Each phase of development is built and verified on a separate Git branch and merged into `main`:
1. `feat/phase-1-core-engine`: Core models, URL parser, multi-segment worker, speed limiter, unit tests.
2. `feat/phase-2-queue-persistence`: Concurrency scheduler, auto-categorization, checksums, persistence.
3. `feat/phase-3-macos-ui`: SwiftUI main view, batch paste sheet, settings, clipboard monitor, notifications.
4. `feat/phase-4-release-packaging`: Standalone `.app` bundle, release checklist, and `v1.0.0` tag.

---

## 📄 License
MIT License. Copyright © 2026 MacDownloader.
