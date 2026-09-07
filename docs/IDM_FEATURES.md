# Internet Download Manager (IDM) Feature Matrix for MacDownloader

This document highlights the beloved features of Internet Download Manager on Windows and how they are implemented natively on macOS in MacDownloader.

| IDM Feature (Windows) | MacDownloader Feature (macOS) | Implementation Details |
| :--- | :--- | :--- |
| **Multi-Part / Accelerated Downloading** | **Dynamic Multi-Segment Range Engine** | Splits file into parallel byte-range streams via HTTP `Range: bytes=X-Y`, downloading segments concurrently and reassembling upon completion. |
| **Batch URL Ingestion** | **Multi-Delimiter Parser** | Paste box supporting comma (`,`), newline (`\n`), semicolon (`;`), or whitespace separated links. |
| **Batch Pattern Grabber** | **Pattern Expander** | Pattern syntax: `https://example.com/file[01-10].mp4` automatically expands to 10 distinct downloads. |
| **Speed Limiter** | **Token-Bucket Rate Limiter** | Real-time bandwidth throttling to prevent network congestion (e.g. 500 KB/s, 2 MB/s, Unlimited). |
| **Automatic File Categorization** | **Smart Directory Routing** | Auto-sorts incoming downloads into `Documents`, `Archives`, `Video`, `Audio`, `Programs`, and `General`. |
| **Clipboard Capture / Sniffer** | **macOS Pasteboard Monitor** | Background observer monitoring `NSPasteboard` change count, catching valid URLs and prompting to download. |
| **Scheduler & Queue Automation** | **Queue Concurrency & Automation** | Queue concurrency pool (1-10 workers), sequential execution, auto-advance, and scheduled triggers. |
| **Resume Interrupted Downloads** | **RFC 9110 HTTP Range Resume** | Tracks downloaded byte offset and `.part` files; sends `Range: bytes={offset}-` on resume. |
| **File Integrity Verification** | **Checksum Verifier (CryptoKit)** | Verifies SHA-256 and MD5 hashes on completed files. |
| **Audio Notification Chimes** | **Native macOS Chimes & Notifications** | System sound feedback upon download completion and UserNotifications banner. |
| **Explorer Integration** | **Finder Integration** | "Reveal in Finder" (`activateFileViewerSelecting`), drag-and-drop support. |
