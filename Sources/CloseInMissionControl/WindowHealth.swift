import AppKit

/// Can this process still put a window on screen?
///
/// Seen on macOS 26.6: after the Mac slept and woke, the app kept working perfectly (events,
/// Accessibility, logging) while none of its windows reached the screen, so there was no ×,
/// no menu-bar icon and not even the welcome window. Only a restart brought them back. The
/// window server is therefore asked directly, using a brand-new, nearly invisible window.
@MainActor
enum WindowHealth {
    /// `--simulate-broken` makes every probe fail, to test the restart path without a sleep.
    private static let simulateBroken = CommandLine.arguments.contains("--simulate-broken")

    /// A sleeping display shows nothing, which is not a fault.
    static var displayIsAwake: Bool { CGDisplayIsAsleep(CGMainDisplayID()) == 0 }

    /// The login session's own description. These keys are not documented by Apple. They are
    /// read only to log what the Mac was doing and to avoid testing behind the lock screen.
    private static var session: [String: Any]? { CGSessionCopyCurrentDictionary() as? [String: Any] }
    static var screenIsLocked: Bool { (session?["CGSSessionScreenIsLocked"] as? Bool) ?? false }
    static var onConsole: Bool { (session?["kCGSSessionOnConsoleKey"] as? Bool) ?? true }

    /// One line for the log with everything that could keep windows off the screen.
    static func describe() -> String {
        "activationPolicy=\(NSApp.activationPolicy().rawValue), active=\(NSApp.isActive), "
            + "hidden=\(NSApp.isHidden), displayAwake=\(displayIsAwake), locked=\(screenIsLocked), "
            + "onConsole=\(onConsole), screens=\(NSScreen.screens.count)"
    }

    /// Puts a 1×1, almost transparent window on screen for a moment and reports whether the
    /// window server agrees that it got there. A new window is used each time on purpose: it
    /// tells "this process cannot show windows" apart from "one old window went stale".
    static func probe(_ done: @escaping @MainActor (Bool) -> Void) {
        guard !simulateBroken else {
            DispatchQueue.main.async { MainActor.assumeIsolated { done(false) } }
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 1, height: 1),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MainActor.assumeIsolated {
                let id = CGWindowID(window.windowNumber)
                let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first
                let onscreen = window.windowNumber > 0 && ((info?[kCGWindowIsOnscreen as String] as? Bool) ?? false)
                window.orderOut(nil)
                done(onscreen)
            }
        }
    }
}
