import AppKit
import CloseInMissionControlCore

/// Accessibility permission: explain first, then let macOS prompt, then watch for the grant.
@MainActor
final class Permission {
    private(set) var isGranted = AXLive.isTrusted
    var onChange: ((Bool) -> Void)?
    private var timer: Timer?

    /// Call once at launch. Shows our own explanation before the system prompt.
    func requestIfNeeded() {
        startWatching()
        guard !isGranted else { return }

        let alert = NSAlert()
        alert.messageText = "Close in Mission Control needs Accessibility access"
        alert.informativeText = """
        It is used for exactly this:
        • reading the position of window thumbnails in Mission Control
        • catching your click on the × and pressing that window's own close button

        This app makes no network connections and collects nothing.
        macOS will now ask you to enable it in System Settings → Privacy & Security → Accessibility.
        """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Quit")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.terminate(nil)
            return
        }
        // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// The grant can be given or revoked at any time, and there is no notification for it.
    private func startWatching() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let now = AXLive.isTrusted
        guard now != isGranted else { return }
        isGranted = now
        onChange?(now)
    }
}
