import SwiftUI
import AppKit
import MacDownloaderCore

public struct MainView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var isDropTargeted: Bool = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $viewModel.selectedCategory) {
                Section("All Downloads") {
                    HStack {
                        Label("All Downloads", systemImage: "tray.full")
                        Spacer()
                        Text("\(viewModel.count(for: nil))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(nil as DownloadCategory?)
                }

                Section("Categories") {
                    ForEach(DownloadCategory.allCases, id: \.self) { cat in
                        HStack {
                            Label(cat.rawValue, systemImage: cat.iconName)
                            Spacer()
                            Text("\(viewModel.count(for: cat))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(cat as DownloadCategory?)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            VStack(spacing: 0) {
                // Header / Filter Bar
                HStack(spacing: 12) {
                    Picker("", selection: $viewModel.selectedStatus) {
                        ForEach(StatusFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 320)

                    Spacer()

                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search downloads...", text: $viewModel.searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 240)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Download Queue List with Drag-and-Drop
                ZStack {
                    if viewModel.filteredItems.isEmpty {
                        emptyQueueView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.filteredItems) { item in
                                    DownloadRowView(item: item, viewModel: viewModel)
                                }
                            }
                            .padding(16)
                        }
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.01).onTapGesture {
                            viewModel.deselectAll()
                        })
                    }

                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .background(Color.accentColor.opacity(0.08))
                            .padding(8)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.accentColor)
                                    Text("Drop URLs or Links to Download")
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                }
                            )
                    }
                }
                .onDrop(of: [.url, .plainText], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                }

                Divider()

                // Bottom Status Bar
                statusBarView
            }
            .background(
                // Invisible buttons to capture keyboard shortcuts
                Group {
                    Button("") {
                        viewModel.deleteSelected(deleteFiles: false)
                    }
                    .keyboardShortcut(.delete, modifiers: [])

                    Button("") {
                        viewModel.deleteSelected(deleteFiles: true)
                    }
                    .keyboardShortcut(.delete, modifiers: .command)

                    Button("") {
                        viewModel.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: .command)

                    Button("") {
                        viewModel.deselectAll()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .frame(width: 0, height: 0)
                .opacity(0)
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { viewModel.isShowingAddSheet = true }) {
                    Label("Add Downloads", systemImage: "plus")
                }
                .help("Add download link(s) (⌘N)")

                if !viewModel.selectedItemIDs.isEmpty {
                    // Selected Items Actions
                    Button(action: { viewModel.resumeSelected() }) {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .help("Resume selected downloads")

                    Button(action: { viewModel.pauseSelected() }) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .help("Pause selected downloads")

                    Menu {
                        Button("Remove from List (\(viewModel.selectedItemIDs.count))") {
                            viewModel.deleteSelected(deleteFiles: false)
                        }
                        Button("Delete Files to Trash (\(viewModel.selectedItemIDs.count))", role: .destructive) {
                            viewModel.deleteSelected(deleteFiles: true)
                        }
                    } label: {
                        Label("Delete (\(viewModel.selectedItemIDs.count))", systemImage: "trash")
                    }
                    .help("Delete selected downloads (⌫)")
                } else {
                    Button(action: { viewModel.scheduler.resumeAll() }) {
                        Label("Start All", systemImage: "play.fill")
                    }
                    .help("Resume all downloads")

                    Button(action: { viewModel.scheduler.pauseAll() }) {
                        Label("Pause All", systemImage: "pause.fill")
                    }
                    .help("Pause all downloads")

                    Menu {
                        Button("Clear Completed") {
                            viewModel.clearCompleted()
                        }
                        Button("Clear Failed / Cancelled") {
                            viewModel.clearFailed()
                        }
                        Divider()
                        Button("Clear All Downloads", role: .destructive) {
                            viewModel.clearAll(deleteFiles: false)
                        }
                        Button("Delete All Files to Trash", role: .destructive) {
                            viewModel.clearAll(deleteFiles: true)
                        }
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .help("Clear queue options")
                }

                Button(action: { viewModel.isShowingSchedulerSheet = true }) {
                    Label("Scheduler", systemImage: "calendar.badge.clock")
                }
                .help("Automated Queue Scheduler")

                Button(action: { FloatingDropTargetManager.shared.toggle() }) {
                    Label("Drop Target", systemImage: "arrow.down.circle")
                }
                .help("Toggle Floating Drop Basket")

                Button(action: { viewModel.isShowingSettingsSheet = true }) {
                    Label("Preferences", systemImage: "gearshape")
                }
                .help("Open Preferences")
            }
        }
        .onAppear {
            MenuBarManager.shared.setup(with: viewModel)
            FloatingDropTargetManager.shared.configure(with: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddSheetNotification)) { _ in
            viewModel.isShowingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .incomingDownloadURLNotification)) { notification in
            if let targetURL = notification.object as? URL {
                viewModel.scheduler.add(urls: [targetURL])
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            BatchAddSheet(viewModel: viewModel, initialText: viewModel.initialAddInput)
        }
        .sheet(isPresented: $viewModel.isShowingSettingsSheet) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingSchedulerSheet) {
            SchedulerSheet(timeScheduler: viewModel.timeScheduler)
        }
        .alert(
            "Download Link Detected",
            isPresented: Binding<Bool>(
                get: { viewModel.detectedClipboardURLs != nil },
                set: { if !$0 { viewModel.detectedClipboardURLs = nil } }
            )
        ) {
            Button("Add to Queue") {
                if let urls = viewModel.detectedClipboardURLs {
                    viewModel.scheduler.add(urls: urls)
                }
                viewModel.detectedClipboardURLs = nil
            }
            Button("Ignore", role: .cancel) {
                viewModel.detectedClipboardURLs = nil
            }
        } message: {
            if let urls = viewModel.detectedClipboardURLs, let first = urls.first {
                Text("Found link in clipboard: \(first.lastPathComponent)\nWould you like to start downloading?")
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        viewModel.initialAddInput = url.absoluteString
                        viewModel.isShowingAddSheet = true
                    }
                }
            }

            _ = provider.loadObject(ofClass: String.self) { text, _ in
                if let text = text {
                    let parsed = URLParser.parse(text: text)
                    if !parsed.isEmpty {
                        DispatchQueue.main.async {
                            viewModel.initialAddInput = parsed.map { $0.absoluteString }.joined(separator: "\n")
                            viewModel.isShowingAddSheet = true
                        }
                    }
                }
            }
        }
        return true
    }

    // MARK: - Subviews

    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))

            Text("No Downloads in Queue")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Paste one or more download links (separated by commas or lines)")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            Button(action: { viewModel.isShowingAddSheet = true }) {
                Label("Add Download(s)", systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBarView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.scheduler.activeCount > 0 ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text("\(viewModel.scheduler.activeCount) active of \(viewModel.scheduler.maxConcurrentDownloads) max")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.scheduler.totalSpeed > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                    Text("Total: \(DownloadItem.formatByteCount(Int64(viewModel.scheduler.totalSpeed)))/s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
            }

            Spacer()

            if !viewModel.selectedItemIDs.isEmpty {
                HStack(spacing: 8) {
                    Text("\(viewModel.selectedItemIDs.count) of \(viewModel.filteredItems.count) selected")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Button("Deselect") {
                        viewModel.deselectAll()
                    }
                    .font(.caption)
                    .buttonStyle(BorderlessButtonStyle())
                }
            } else {
                Text("\(viewModel.filteredItems.count) item\(viewModel.filteredItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
