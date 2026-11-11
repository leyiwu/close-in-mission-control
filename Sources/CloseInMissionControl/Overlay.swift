import AppKit

/// The one window this app ever shows: a small × that floats above Mission Control.
/// It is purely visual. Mission Control does not deliver clicks to other apps' windows,
/// so the click is handled by `ClickInterceptor`.
@MainActor
final class Overlay {
    static let size: CGFloat = 26
    private let panel: NSPanel
    private let button: CloseButtonView
    private(set) var isVisible = false

    init() {
        button = CloseButtonView(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        // Undocumented dependency: this level and `.stationary` keep the panel visible
        // above Mission Control. See DEPENDENCIES.md #4.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = button
    }

    func setHighlighted(_ highlighted: Bool) {
        if button.highlighted != highlighted { button.highlighted = highlighted }
    }

    /// `topLeft` is in AX coordinates (origin at the top-left of the primary display).
    func show(atAXTopLeft topLeft: CGPoint) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let origin = NSPoint(x: topLeft.x, y: primaryHeight - topLeft.y - Self.size)
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
        if !isVisible {
            panel.orderFrontRegardless()
            isVisible = true
        }
    }

    func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CloseButtonView: NSView {
    var highlighted = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let circle = bounds.insetBy(dx: 2, dy: 2)
        (highlighted ? NSColor.systemRed : NSColor.black.withAlphaComponent(0.55)).setFill()
        NSBezierPath(ovalIn: circle).fill()
        NSColor.white.withAlphaComponent(0.35).setStroke()
        let ring = NSBezierPath(ovalIn: circle.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()

        let arm = circle.width * 0.2
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: center.x - arm, y: center.y - arm))
        cross.line(to: NSPoint(x: center.x + arm, y: center.y + arm))
        cross.move(to: NSPoint(x: center.x - arm, y: center.y + arm))
        cross.line(to: NSPoint(x: center.x + arm, y: center.y - arm))
        cross.lineWidth = 1.8
        cross.lineCapStyle = .round
        NSColor.white.setStroke()
        cross.stroke()
    }
}
