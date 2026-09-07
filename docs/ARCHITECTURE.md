# MacDownloader: System Architecture & Design

## 1. Architectural Overview

MacDownloader follows a unidirectional data flow and clean decoupled layered architecture tailored for high throughput, thread safety, and responsive UI performance on macOS.

```
+--------------------------------------------------------------+
|                         SwiftUI UI                           |
|  [MainView]   [BatchAddSheet]   [SettingsView]   [FilterBar] |
+--------------------------------------------------------------+
                                |
                                v
+--------------------------------------------------------------+
|               AppViewModel (MainActor Observable)            |
|  Bridges UI state with Core Queue, Filters, and Clipboard   |
+--------------------------------------------------------------+
                                |
                                v
+--------------------------------------------------------------+
|               QueueScheduler (Concurrency Pool)              |
|  - Max concurrency worker management (default 3)            |
|  - Auto-advancing FIFO / Priority Dispatching               |
|  - Pause All / Resume All orchestration                     |
+--------------------------------------------------------------+
        /                       |                       \
       v                        v                        v
+------------------+  +-------------------+  +-------------------+
|  DownloadWorker  |  |  CategoryManager  |  | PersistenceEngine |
| - URLSession Task|  | - Smart Directory |  | - JSON serialization|
| - Byte-Ranges    |  |   Routing (Docs,  |  | - Crash recovery  |
| - SpeedLimiter   |  |   Media, Archives)|  | - Part files       |
+------------------+  +-------------------+  +-------------------+
```

## 2. Core Modules

### 2.1 Engine Module (`MacDownloaderCore/Engine`)
- **`URLParser`**: Stateless utility parsing raw pasted strings with multi-delimiters (commas, newlines, semicolons), regex pattern expansion (`[01-20]`), URL normalization, and filename guessing from paths and query strings.
- **`DownloadWorker`**: State-managed asynchronous worker executing network requests via `URLSession`. Supports HTTP byte ranges (`Range: bytes=offset-`), streaming chunks directly to disk to minimize memory footprint, rolling-average speed tracking, and auto-retry on network drop.
- **`SpeedLimiter`**: Token-bucket rate limiter that throttles data read rates based on user-configured limits.

### 2.2 Queue Module (`MacDownloaderCore/Queue`)
- **`QueueScheduler`**: Central coordinator holding active, queued, paused, completed, and failed tasks. Enforces worker limits, handles scheduling priorities, and dispatches next items automatically when slots free up.

### 2.3 Storage & Persistence (`MacDownloaderCore/Storage`)
- **`PersistenceManager`**: Thread-safe manager persisting task metadata to `queue.json` in application support directory. Ensures in-flight downloads can resume exactly where they left off after an app reboot.
- **`CategoryManager`**: Maps MIME types and file extensions into dedicated folders (Documents, Video, Audio, Archives, Programs).
- **`ChecksumVerifier`**: Cryptographic integrity engine calculating SHA-256 and MD5 hashes using Apple's `CryptoKit`.

### 2.4 UI & System Services (`MacDownloaderApp`)
- **`MacDownloaderApp`**: Root SwiftUI application lifecycle.
- **`ClipboardMonitor`**: Observes system `NSPasteboard` change count and captures URLs when copying links.
- **`NotificationManager`**: Triggers macOS system notifications and completion chimes.
