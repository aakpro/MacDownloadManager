import SwiftUI
import AppKit
import MacDownloaderCore

public struct BatchAddSheet: View {
    @ObservedObject public var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var patternInput: String = "https://example.com/file[01-05].zip"
    @State private var selectedTab: Int = 0 // 0: Paste, 1: Pattern
    @State private var extensionFilter: String = ""
    @State private var customFolder: URL? = nil
    @State private var startImmediately: Bool = true

    public init(viewModel: AppViewModel, initialText: String = "") {
        self.viewModel = viewModel
        self._inputText = State(initialValue: initialText)
    }

    private var parsedURLs: [URL] {
        let textToParse = selectedTab == 0 ? inputText : patternInput
        return URLParser.parse(text: textToParse, filterExtension: extensionFilter.isEmpty ? nil : extensionFilter)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Add Downloads")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            // Mode Picker
            Picker("", selection: $selectedTab) {
                Text("Paste Links").tag(0)
                Text("Batch Pattern Generator").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())

            if selectedTab == 0 {
                // Multi-link paste box
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste download URL(s) separated by commas or newlines:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 140)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
            } else {
                // Pattern Generator
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter URL pattern with brackets e.g. [01-10] or [1-20]:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("https://example.com/item[01-10].zip", text: $patternInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))

                    Text("Example: https://cdn.site.org/book_ch[01-12].pdf")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(height: 140, alignment: .top)
            }

            // Options: Extension filter & Target Destination
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Filter by Extension:")
                        .font(.caption)
                    TextField("e.g. mp4, zip (optional)", text: $extensionFilter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 160)
                }

                HStack {
                    Text("Save To:")
                        .font(.caption)
                    Text(customFolder?.path ?? "Default Category Folders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse...") {
                        selectDestinationDirectory()
                    }
                    .font(.caption)
                }

                Toggle("Start downloading immediately", isOn: $startImmediately)
                    .font(.caption)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Detected Files Preview
            if !parsedURLs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detected Files Preview (\(parsedURLs.count)):")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(parsedURLs.prefix(8), id: \.self) { url in
                                HStack(spacing: 6) {
                                    Image(systemName: DownloadCategory.detect(from: DownloadItem.extractFilename(from: url)).iconName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(DownloadItem.extractFilename(from: url))
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            if parsedURLs.count > 8 {
                                Text("... and \(parsedURLs.count - 8) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 80)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Footer: URL Count badge + Add button
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(parsedURLs.isEmpty ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(parsedURLs.count) valid download\(parsedURLs.count == 1 ? "" : "s") detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add to Queue") {
                    addDownloads()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .disabled(parsedURLs.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private func addDownloads() {
        let urls = parsedURLs
        guard !urls.isEmpty else { return }

        viewModel.scheduler.add(
            urls: urls,
            destinationFolder: customFolder,
            startImmediately: startImmediately
        )
        dismiss()
    }

    private func selectDestinationDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Download Folder"

        if panel.runModal() == .OK, let selected = panel.url {
            self.customFolder = selected
        }
    }
}
