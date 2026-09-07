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
        return true
    }
}

extension Notification.Name {
    static let openAddSheetNotification = Notification.Name("openAddSheetNotification")
}
