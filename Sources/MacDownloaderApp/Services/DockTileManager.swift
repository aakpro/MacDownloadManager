import AppKit

/// Updates macOS Dock tile with dynamic active badges and custom progress bar overlay.
@MainActor
public final class DockTileManager {
    public static let shared = DockTileManager()

    private let dockTile = NSApp.dockTile
    private lazy var progressView = DockProgressView(frame: NSRect(x: 0, y: 0, width: dockTile.size.width, height: dockTile.size.height))

    private init() {
        dockTile.contentView = progressView
    }

    /// Updates dock tile badge and progress bar.
    public func update(activeCount: Int, progressRatio: Double) {
        if activeCount > 0 {
            dockTile.badgeLabel = "\(activeCount)"
            progressView.progress = progressRatio
            progressView.isActive = true
        } else {
            dockTile.badgeLabel = nil
            progressView.progress = 0
            progressView.isActive = false
        }
        dockTile.display()
    }
}

private final class DockProgressView: NSView {
    var progress: Double = 0.0 {
        didSet { needsDisplay = true }
    }
    var isActive: Bool = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw standard app icon
        let icon = NSApp.applicationIconImage ?? (Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap { NSImage(contentsOf: $0) })
        icon?.draw(in: bounds)

        guard isActive else { return }

        // Render progress bar overlay near bottom of tile
        let barHeight: CGFloat = 16
        let margin: CGFloat = 8
        let barRect = NSRect(x: margin, y: margin + 4, width: bounds.width - (margin * 2), height: barHeight)

        let bgPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        NSColor.black.withAlphaComponent(0.65).setFill()
        bgPath.fill()

        let strokePath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        NSColor.white.withAlphaComponent(0.25).setStroke()
        strokePath.lineWidth = 1.0
        strokePath.stroke()

        if progress > 0 {
            let fillWidth = max(barHeight, barRect.width * CGFloat(min(1.0, progress)))
            let fillRect = NSRect(x: margin, y: margin + 4, width: fillWidth, height: barHeight)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
            NSColor.systemBlue.setFill()
            fillPath.fill()
        }
    }
}
