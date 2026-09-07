import SwiftUI
import AppKit
import MacDownloaderCore

@main
struct MacDownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 520)
                .onOpenURL { url in
                    if url.scheme == "macdownloader" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let targetStr = components.queryItems?.first(where: { $0.name == "url" })?.value,
                           let targetURL = URL(string: targetStr) {
                            NotificationCenter.default.post(name: .incomingDownloadURLNotification, object: targetURL)
                        }
                    }
                }
        }
        .windowStyle(TitleBarWindowStyle())
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Downloads...") {
                    NotificationCenter.default.post(name: .openAddSheetNotification, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Retain background menu bar helper when main window closes
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

extension Notification.Name {
    static let openAddSheetNotification = Notification.Name("openAddSheetNotification")
    static let incomingDownloadURLNotification = Notification.Name("incomingDownloadURLNotification")
}
