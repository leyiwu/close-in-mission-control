import AppKit
import CloseInMissionControlCore

/// Accessibility permission: the state, a watcher for changes, and the two ways to ask.
/// The explanation shown to the user lives in `WelcomeWindow`.
@MainActor
final class Permission {
    private(set) var isGranted = AXLive.isTrusted
    /// Called with the new state whenever the grant is given or revoked.
    var onChange: ((Bool) -> Void)?
    private var timer: Timer?

    /// The grant can be given or revoked at any time, and macOS sends no notification for
    /// it, so poll.
    func startWatching() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Adds the app to the Accessibility list and shows macOS's own prompt, which has a
    /// button that opens System Settings.
    func showSystemPrompt() {
        // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func refresh() {
        let now = AXLive.isTrusted
        guard now != isGranted else { return }
        isGranted = now
        onChange?(now)
    }
}
