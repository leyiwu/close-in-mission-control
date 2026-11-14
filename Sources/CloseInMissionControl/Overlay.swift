import AppKit

/// The one window this app ever shows: a small × that floats above Mission Control.
/// It is purely visual. Mission Control does not deliver clicks to other apps' windows,
/// so the click is handled by `ClickInterceptor`.
@MainActor
final class Overlay {
    static let size: CGFloat = 21
    /// The × is already visible the instant the pointer arrives, then settles to full
    /// strength: a response that feels immediate, with a motion that can still be seen.
    private static let fadeStartAlpha: CGFloat = 0.3
    private static let fadeDuration: TimeInterval = 0.2
    private let panel: NSPanel
    private let button: CloseButtonView
    private(set) var isVisible = false
    /// The origin last asked for. Compared instead of the panel's own frame, which AppKit
    /// may round, so that "did it move?" stays reliable at 20 calls a second.
    private var requestedOrigin: NSPoint?

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
        let moved = origin != requestedOrigin
        if moved {
            requestedOrigin = origin
            panel.setFrameOrigin(origin)
        }
        if !isVisible {
            panel.alphaValue = Self.fadeStartAlpha
            panel.orderFrontRegardless()
            isVisible = true
            fadeIn()
        } else if moved {
            // Jumped straight to another thumbnail: fade in there too.
            panel.alphaValue = Self.fadeStartAlpha
            fadeIn()
        }
    }

    /// A short fade from a visible start, so the × settles in instead of popping. Skipped when the user has
    /// asked macOS to reduce motion.
    private func fadeIn() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { return }
        // Hiding is instant: after a click the × must vanish at once. A zero-length
        // animation also cancels a fade that is still running.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 0
        }
        panel.orderOut(nil)
        isVisible = false
        requestedOrigin = nil
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CloseButtonView: NSView {
    var highlighted = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        // Silver disc that turns grey under the pointer, like a tint laid over it.
        let circle = bounds.insetBy(dx: 1.5, dy: 1.5)
        // Default is a bright silver, lighter than MacBook "Silver" (about #F5F5F7).
        let fill = highlighted
            ? NSColor(white: 0.52, alpha: 1)
            : NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1)
        fill.setFill()
        NSBezierPath(ovalIn: circle).fill()
        NSColor(white: highlighted ? 1 : 0, alpha: highlighted ? 0.5 : 0.18).setStroke()
        let ring = NSBezierPath(ovalIn: circle.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()

        let arm: CGFloat = 2.8 // fixed glyph size, independent of the disc
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: center.x - arm, y: center.y - arm))
        cross.line(to: NSPoint(x: center.x + arm, y: center.y + arm))
        cross.move(to: NSPoint(x: center.x - arm, y: center.y + arm))
        cross.line(to: NSPoint(x: center.x + arm, y: center.y - arm))
        cross.lineWidth = 1.3
        cross.lineCapStyle = .round
        // Dark glyph: white would wash out against silver.
        NSColor(white: 0.16, alpha: 1).setStroke()
        cross.stroke()
    }
}
