import AppKit
import SwiftUI
import MacDownloaderCore

/// Manages an IDM-style floating drop basket that stays on top of all windows.
@MainActor
public final class FloatingDropTargetManager: ObservableObject {
    public static let shared = FloatingDropTargetManager()

    @Published public private(set) var isVisible: Bool = false
    private var panel: NSPanel?
    private weak var viewModel: AppViewModel?

    private init() {}

    public func configure(with viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard !isVisible else { return }

        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 120, y: 120, width: 100, height: 100),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.titlebarAppearsTransparent = true
            p.titleVisibility = .hidden
            p.isMovableByWindowBackground = true
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true

            let rootView = FloatingDropView { [weak self] urls in
                self?.viewModel?.scheduler.add(urls: urls)
            }
            p.contentView = NSHostingView(rootView: rootView)
            self.panel = p
        }

        panel?.orderFront(nil)
        isVisible = true
    }

    public func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }
}

private struct FloatingDropView: View {
    let onDropURLs: ([URL]) -> Void
    @State private var isTargeted: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThin)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: isTargeted ? 2.5 : 1
                        )
                )

            VStack(spacing: 4) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundColor(isTargeted ? .accentColor : .primary)

                Text(isTargeted ? "Release" : "Drop Links")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 95, height: 95)
        .onDrop(of: [.url, .plainText], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            onDropURLs([url])
                        }
                    }
                }
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    if let text = text {
                        let parsed = URLParser.parse(text: text)
                        if !parsed.isEmpty {
                            DispatchQueue.main.async {
                                onDropURLs(parsed)
                            }
                        }
                    }
                }
            }
            return true
        }
    }
}
