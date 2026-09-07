import Foundation
import AppKit

/// Post-download actions executed when the entire queue completes.
public enum PostDownloadAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "None"
    case sleepMac = "Put Mac to Sleep"
    case shutdownMac = "Shut Down Mac"

    public var id: String { rawValue }
}

/// Manages macOS system power assertions to prevent idle sleep during active downloads
/// and executes post-completion power actions (sleep / shutdown).
@MainActor
public final class PowerManager: ObservableObject {
    public static let shared = PowerManager()

    @Published public var preventSleepWhileDownloading: Bool {
        didSet {
            UserDefaults.standard.set(preventSleepWhileDownloading, forKey: "preventSleepWhileDownloading")
            updateAssertion(hasActiveDownloads: currentHasActiveDownloads)
        }
    }

    @Published public var postDownloadAction: PostDownloadAction {
        didSet {
            UserDefaults.standard.set(postDownloadAction.rawValue, forKey: "postDownloadAction")
        }
    }

    private var activityToken: NSObjectProtocol?
    private var currentHasActiveDownloads: Bool = false

    private init() {
        self.preventSleepWhileDownloading = UserDefaults.standard.object(forKey: "preventSleepWhileDownloading") as? Bool ?? true
        if let raw = UserDefaults.standard.string(forKey: "postDownloadAction"),
           let action = PostDownloadAction(rawValue: raw) {
            self.postDownloadAction = action
        } else {
            self.postDownloadAction = .none
        }
    }

    /// Updates power assertions based on whether active downloads are in progress.
    public func updateAssertion(hasActiveDownloads: Bool) {
        self.currentHasActiveDownloads = hasActiveDownloads

        if hasActiveDownloads && preventSleepWhileDownloading {
            if activityToken == nil {
                activityToken = ProcessInfo.processInfo.beginActivity(
                    options: [.idleSystemSleepDisabled, .userInitiated],
                    reason: "MacDownloader active downloads in progress"
                )
            }
        } else {
            if let token = activityToken {
                ProcessInfo.processInfo.endActivity(token)
                activityToken = nil
            }
        }
    }

    /// Triggers configured post-completion action when the queue finishes.
    public func handleQueueCompleted() {
        // Release power assertion
        updateAssertion(hasActiveDownloads: false)

        switch postDownloadAction {
        case .none:
            break
        case .sleepMac:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let script = "tell application \"Finder\" to sleep"
                var error: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&error)
            }
        case .shutdownMac:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let script = "tell application \"Finder\" to shut down"
                var error: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&error)
            }
        }
    }

    public func cleanup() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }
}
