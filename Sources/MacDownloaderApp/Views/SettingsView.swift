import SwiftUI
import AppKit
import MacDownloaderCore

public struct SettingsView: View {
    @ObservedObject public var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var maxConcurrent: Int
    @State private var speedLimitOption: Int = 0 // 0: Unlimited, 1: 500KB, 2: 1MB, 3: 2MB, 4: 5MB
    @State private var autoCategorize: Bool
    @State private var soundEnabled: Bool
    @State private var notificationsEnabled: Bool
    @State private var clipboardEnabled: Bool

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        self._maxConcurrent = State(initialValue: viewModel.scheduler.maxConcurrentDownloads)
        self._autoCategorize = State(initialValue: viewModel.scheduler.categoryManager.isAutoCategorizationEnabled)
        self._soundEnabled = State(initialValue: viewModel.notificationManager.isSoundEnabled)
        self._notificationsEnabled = State(initialValue: viewModel.notificationManager.areNotificationsEnabled)
        self._clipboardEnabled = State(initialValue: viewModel.clipboardMonitor.isMonitoringEnabled)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Preferences")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Form {
                // Section 1: Concurrency & Bandwidth
                Section(header: Text("Queue & Speed").font(.headline)) {
                    Stepper("Max Concurrent Downloads: \(maxConcurrent)", value: $maxConcurrent, in: 1...10)
                        .onChange(of: maxConcurrent) { _, newValue in
                            viewModel.scheduler.maxConcurrentDownloads = newValue
                        }

                    Picker("Speed Limiter:", selection: $speedLimitOption) {
                        Text("Unlimited").tag(0)
                        Text("500 KB/s").tag(1)
                        Text("1 MB/s").tag(2)
                        Text("2 MB/s").tag(3)
                        Text("5 MB/s").tag(4)
                    }
                    .onChange(of: speedLimitOption) { _, newValue in
                        applySpeedLimit(newValue)
                    }
                }

                Divider()

                // Section 2: Storage & Categorization
                Section(header: Text("Categorization & Storage").font(.headline)) {
                    Toggle("Enable IDM Smart Categorization", isOn: $autoCategorize)
                        .onChange(of: autoCategorize) { _, newValue in
                            viewModel.scheduler.categoryManager.isAutoCategorizationEnabled = newValue
                        }

                    Text("Automatically sorts into Documents, Archives, Video, Audio, and Programs folders.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Base Download Folder:")
                        Spacer()
                        Text(viewModel.scheduler.categoryManager.defaultBaseFolder.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Change...") {
                            selectBaseDirectory()
                        }
                    }
                }

                Divider()

                // Section 3: Automation & Feedback
                Section(header: Text("System & Automation").font(.headline)) {
                    Toggle("Monitor Clipboard for Download Links", isOn: $clipboardEnabled)
                        .onChange(of: clipboardEnabled) { _, newValue in
                            viewModel.clipboardMonitor.isMonitoringEnabled = newValue
                        }

                    Toggle("Enable Native macOS Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            viewModel.notificationManager.areNotificationsEnabled = newValue
                        }

                    Toggle("Play Audio Chime on Completion", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { _, newValue in
                            viewModel.notificationManager.isSoundEnabled = newValue
                        }
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func applySpeedLimit(_ option: Int) {
        let bytesPerSec: Int64
        switch option {
        case 1: bytesPerSec = 500 * 1024
        case 2: bytesPerSec = 1024 * 1024
        case 3: bytesPerSec = 2 * 1024 * 1024
        case 4: bytesPerSec = 5 * 1024 * 1024
        default: bytesPerSec = 0
        }
        viewModel.scheduler.setSpeedLimit(bytesPerSecond: bytesPerSec)
    }

    private func selectBaseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Base Folder"

        if panel.runModal() == .OK, let selected = panel.url {
            viewModel.scheduler.categoryManager.defaultBaseFolder = selected
        }
    }
}
