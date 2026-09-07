import Foundation
import AppKit
import UserNotifications
import MacDownloaderCore

/// Manages native macOS system notifications and audio completion feedback.
@MainActor
public final class NotificationManager: NSObject, Sendable {
    public static let shared = NotificationManager()

    public var isSoundEnabled: Bool = true
    public var areNotificationsEnabled: Bool = true

    private override init() {
        super.init()
        requestNotificationAuthorization()
    }

    public func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            // Authorization handled
        }
    }

    /// Plays an audio chime when a download completes or fails.
    public func playCompletionSound(isSuccess: Bool = true) {
        guard isSoundEnabled else { return }
        if isSuccess {
            NSSound(named: "Glass")?.play()
        } else {
            NSSound(named: "Basso")?.play()
        }
    }

    /// Posts a user notification for a completed download.
    public func postDownloadCompletedNotification(for item: DownloadItem) {
        guard areNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.subtitle = item.filename
        content.body = "Saved to \(item.destinationFolder.lastPathComponent). Size: \(DownloadItem.formatByteCount(item.totalBytes > 0 ? item.totalBytes : item.downloadedBytes))"
        content.sound = isSoundEnabled ? .default : nil

        let request = UNNotificationRequest(
            identifier: "complete_\(item.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Posts an error notification when a download fails.
    public func postDownloadFailedNotification(for item: DownloadItem, error: Error) {
        guard areNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.subtitle = item.filename
        content.body = error.localizedDescription
        content.sound = isSoundEnabled ? .defaultCritical : nil

        let request = UNNotificationRequest(
            identifier: "fail_\(item.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
