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
    private static let fadeDuration: TimeInterval = 0.12
    private var panel: NSPanel
    private var button: CloseButtonView
    /// Called (at most every ten seconds) when the window server does not consider the panel
    /// to be on screen although it was just shown.
    var onSuspect: (() -> Void)?
    private var lastSuspect = Date.distantPast
    private(set) var isVisible = false
    /// The origin last asked for. Compared instead of the panel's own frame, which AppKit
    /// may round, so that "did it move?" stays reliable at 20 calls a second.
    private var requestedOrigin: NSPoint?
    /// The self-check logs its first few successes, and a failure at most every ten seconds.
    private var checksLogged = 0
    private var lastFailureLog = Date.distantPast

    init() {
        let made = Self.makePanel()
        panel = made.panel
        button = made.button
    }

    private static func makePanel() -> (panel: NSPanel, button: CloseButtonView) {
        let button = CloseButtonView(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        let panel = OverlayPanel(
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
        // The window itself is always fully opaque. The fade is drawn on the button's layer,
        // so no sequence of shows and hides can leave the window on screen but invisible.
        panel.alphaValue = 1
        panel.contentView = button
        return (panel, button)
    }

    /// Replaces the panel with a brand-new one, for when only this window has gone stale.
    func rebuild() {
        let highlighted = button.highlighted
        panel.orderOut(nil)
        let made = Self.makePanel()
        panel = made.panel
        button = made.button
        button.highlighted = highlighted
        isVisible = false
        requestedOrigin = nil
        Log.write("overlay panel rebuilt")
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
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            isVisible = true
            fadeIn()
            scheduleCheck()
        } else if moved {
            // Jumped straight to another thumbnail: fade in there too.
            fadeIn()
        }
    }

    /// A short fade from a visible start, so the × settles in instead of popping. It only
    /// animates the button's layer, whose resting opacity is 1: if the animation never runs
    /// the × is simply fully visible. Skipped when the user has asked macOS to reduce motion.
    private func fadeIn() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer = button.layer else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = Self.fadeStartAlpha
        fade.toValue = 1
        fade.duration = Self.fadeDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(fade, forKey: "fadeIn") // replaces a fade that is still running
    }

    func hide() {
        guard isVisible else { return }
        // Hiding is instant: after a click the × must vanish at once.
        panel.orderOut(nil)
        button.layer?.removeAnimation(forKey: "fadeIn")
        isVisible = false
        requestedOrigin = nil
    }

    // MARK: - Self-check

    /// Shortly after the panel is shown, asks the window server whether it really is on
    /// screen. The app's own bookkeeping can say "shown" while the window is not, which once
    /// looked like a × that never appeared. If so, the details are logged and the panel is
    /// brought forward again.
    private func scheduleCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            MainActor.assumeIsolated { self?.verifyOnScreen() }
        }
    }

    private func verifyOnScreen() {
        guard isVisible, panel.windowNumber > 0 else { return } // hidden again meanwhile
        let id = CGWindowID(panel.windowNumber)
        let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first
        let onscreen = (info?[kCGWindowIsOnscreen as String] as? Bool) ?? false
        let alpha = (info?[kCGWindowAlpha as String] as? Double) ?? -1
        if onscreen, alpha > 0.5 {
            if checksLogged < 3 {
                checksLogged += 1
                Log.write("overlay check ok (on screen, alpha \(alpha))")
            }
            return
        }
        if Date().timeIntervalSince(lastFailureLog) > 10 {
            lastFailureLog = Date()
            Log.write("overlay NOT on screen although shown: onscreen=\(onscreen), alpha=\(alpha), "
                + "level=\(panel.level.rawValue), frame=\(NSStringFromRect(panel.frame)), "
                + WindowHealth.describe())
        }
        panel.orderFrontRegardless()
        // Not on screen at all, with the window itself fully opaque, is the fault seen after a
        // sleep. (A near-zero alpha while on screen is only macOS fading the window in or out.)
        if !onscreen, alpha > 0.5, Date().timeIntervalSince(lastSuspect) > 10 {
            lastSuspect = Date()
            onSuspect?()
        }
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CloseButtonView: NSView {
    var highlighted = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true // the fade animates this view's layer
    }

    required init?(coder: NSCoder) { fatalError("not used") }

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
