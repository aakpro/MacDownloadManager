import SwiftUI
import AppKit
import MacDownloaderCore

public struct DownloadRowView: View {
    public let item: DownloadItem
    @ObservedObject public var viewModel: AppViewModel

    public init(item: DownloadItem, viewModel: AppViewModel) {
        self.item = item
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Icon + Filename + Status Badge
            HStack(spacing: 10) {
                Image(systemName: item.category.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(categoryColor(for: item.category))
                    .frame(width: 32, height: 32)
                    .background(categoryColor(for: item.category).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.filename)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.url.host ?? item.url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusBadge(for: item.status)
            }

            // Progress Bar
            if item.status == .downloading || item.status == .paused || item.status == .connecting {
                ProgressView(value: item.progressRatio, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: item.status)))
            } else if item.status == .completed {
                ProgressView(value: 1.0, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }

            // Metrics row: Size, Speed, ETA & Actions
            HStack(alignment: .center) {
                // Size & Speed & ETA
                HStack(spacing: 12) {
                    Label(item.formattedSize, systemImage: "internaldrive")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if item.status.isActive && item.speed > 0 {
                        Label(item.formattedSpeed, systemImage: "bolt.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)

                        if let _ = item.eta {
                            Label(item.formattedETA, systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = item.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 6) {
                    if item.status == .downloading || item.status == .connecting {
                        Button(action: { viewModel.scheduler.pause(id: item.id) }) {
                            Image(systemName: "pause.fill")
                        }
                        .help("Pause Download")
                    } else if item.status == .paused {
                        Button(action: { viewModel.scheduler.resume(id: item.id) }) {
                            Image(systemName: "play.fill")
                        }
                        .help("Resume Download")
                    } else if item.status == .failed || item.status == .cancelled {
                        Button(action: { viewModel.scheduler.retry(id: item.id) }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Retry Download")
                    }

                    if item.status == .completed {
                        Button(action: { viewModel.revealInFinder(for: item) }) {
                            Image(systemName: "folder")
                        }
                        .help("Reveal in Finder")
                    }

                    Menu {
                        Button("Reveal in Finder") {
                            viewModel.revealInFinder(for: item)
                        }
                        Button("Copy Link") {
                            viewModel.copyDownloadLink(for: item)
                        }
                        Divider()
                        if item.status.canPause {
                            Button("Pause") { viewModel.scheduler.pause(id: item.id) }
                        }
                        if item.status.canResume {
                            Button("Resume") { viewModel.scheduler.resume(id: item.id) }
                        }
                        if !item.status.isTerminal {
                            Button("Cancel") { viewModel.scheduler.cancel(id: item.id) }
                        }
                        Divider()
                        Button("Remove from List", role: .destructive) {
                            viewModel.scheduler.remove(id: item.id, deleteFiles: false)
                        }
                        Button("Delete File", role: .destructive) {
                            viewModel.scheduler.remove(id: item.id, deleteFiles: true)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 24)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button("Reveal in Finder") {
                viewModel.revealInFinder(for: item)
            }
            Button("Copy Link") {
                viewModel.copyDownloadLink(for: item)
            }
            Divider()
            if item.status.canPause {
                Button("Pause") { viewModel.scheduler.pause(id: item.id) }
            }
            if item.status.canResume {
                Button("Resume") { viewModel.scheduler.resume(id: item.id) }
            }
            Divider()
            Button("Remove from List") {
                viewModel.scheduler.remove(id: item.id, deleteFiles: false)
            }
            Button("Delete File", role: .destructive) {
                viewModel.scheduler.remove(id: item.id, deleteFiles: true)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusBadge(for status: DownloadStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.15))
            .foregroundColor(statusColor(for: status))
            .clipShape(Capsule())
    }

    private func statusColor(for status: DownloadStatus) -> Color {
        switch status {
        case .queued: return .gray
        case .connecting: return .purple
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    private func progressColor(for status: DownloadStatus) -> Color {
        switch status {
        case .paused: return .orange
        default: return .blue
        }
    }

    private func categoryColor(for category: DownloadCategory) -> Color {
        switch category {
        case .documents: return .blue
        case .archives: return .orange
        case .video: return .purple
        case .audio: return .pink
        case .programs: return .green
        case .general: return .gray
        }
    }
}
