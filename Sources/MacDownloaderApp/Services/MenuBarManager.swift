import AppKit
import Combine
import MacDownloaderCore

/// Manages the macOS Menu Bar Status Item (NSStatusItem) for background queue monitoring.
@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private weak var viewModel: AppViewModel?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    /// Configures the menu bar item with the app view model.
    public func setup(with viewModel: AppViewModel) {
        self.viewModel = viewModel

        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "MacDownloader")
            button.imagePosition = .imageLeading
            button.title = ""
        }

        self.statusItem = item
        buildMenu()

        // Observe changes to scheduler items
        viewModel.scheduler.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }

    public func updateStatusItem() {
        guard let item = statusItem, let button = item.button, let vm = viewModel else { return }

        let activeItems = vm.scheduler.items.filter { $0.status.isActive }
        let totalSpeed = activeItems.reduce(0.0) { $0 + $1.speed }

        if !activeItems.isEmpty {
            button.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "MacDownloader")
            if totalSpeed > 0 {
                button.title = " " + DownloadItem.formatByteCount(Int64(totalSpeed)) + "/s"
            } else {
                button.title = " (\(activeItems.count))"
            }
        } else {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "MacDownloader")
            button.title = ""
        }

        buildMenu()
    }

    private func buildMenu() {
        guard let item = statusItem, let vm = viewModel else { return }

        let menu = NSMenu()
        let activeItems = vm.scheduler.items.filter { $0.status.isActive }

        // Header Item
        let headerTitle = activeItems.isEmpty
            ? "MacDownloader - Idle"
            : "MacDownloader - \(activeItems.count) Active (\(DownloadItem.formatByteCount(Int64(activeItems.reduce(0.0) { $0 + $1.speed })))/s)"
        let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Active downloads list (up to 5 items)
        if !activeItems.isEmpty {
            for download in activeItems.prefix(5) {
                let progress = download.formattedProgress
                let speed = download.speed > 0 ? " • \(download.formattedSpeed)" : ""
                let title = "  \(download.filename) (\(progress)\(speed))"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // Global Controls
        let pauseAllItem = NSMenuItem(title: "Pause All Downloads", action: #selector(pauseAllAction), keyEquivalent: "")
        pauseAllItem.target = self
        pauseAllItem.isEnabled = !activeItems.isEmpty
        menu.addItem(pauseAllItem)

        let resumeAllItem = NSMenuItem(title: "Resume All Downloads", action: #selector(resumeAllAction), keyEquivalent: "")
        resumeAllItem.target = self
        resumeAllItem.isEnabled = vm.scheduler.items.contains { $0.status == .paused || $0.status == .queued }
        menu.addItem(resumeAllItem)

        menu.addItem(NSMenuItem.separator())

        // Add Links & Window Actions
        let addItem = NSMenuItem(title: "Add Links...", action: #selector(addLinksAction), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        let openAppItem = NSMenuItem(title: "Open MacDownloader", action: #selector(openAppAction), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(NSMenuItem.separator())

        // Quit Action
        let quitItem = NSMenuItem(title: "Quit MacDownloader", action: #selector(quitAppAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func pauseAllAction() {
        viewModel?.scheduler.pauseAll()
    }

    @objc private func resumeAllAction() {
        viewModel?.scheduler.resumeAll()
    }

    @objc private func addLinksAction() {
        openAppAction()
        viewModel?.isShowingAddSheet = true
    }

    @objc private func openAppAction() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
        }
    }

    @objc private func quitAppAction() {
        NSApp.terminate(nil)
    }
}
