import AppKit
import CloseInMissionControlCore

/// A real window: what the matcher compares, plus the AX handle used to close it.
struct LiveWindow: @unchecked Sendable {
    var candidate: WindowCandidate
    var element: AXUIElement
    var appName: String
    /// Position in the app's own AXWindows list (0 = first, normally the frontmost).
    var indexInApp: Int
}

/// Lists every regular app's windows through Accessibility.
///
/// Each app is asked on a background thread and reported as soon as it answers, so one
/// unresponsive app (seen: QuickTime Player timing out) never delays the others.
@MainActor
final class WindowDirectory {
    /// Called with an app's complete, current window list each time that app answers.
    var onUpdate: ((pid_t, [LiveWindow]) -> Void)?
    private var inFlight: Set<pid_t> = []
    private var reportedFailures: Set<pid_t> = []

    /// Starts a refresh and returns the pids of all running regular apps.
    @discardableResult
    func refresh() -> Set<pid_t> {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for app in apps {
            let pid = app.processIdentifier
            let name = app.localizedName ?? "?"
            guard !inFlight.contains(pid) else { continue } // still waiting on an earlier request
            inFlight.insert(pid)
            DispatchQueue.global(qos: .userInitiated).async {
                let (error, windows) = Self.read(pid: pid, appName: name)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.finish(pid: pid, name: name, error: error, windows: windows) }
                }
            }
        }
        return Set(apps.map(\.processIdentifier))
    }

    private func finish(pid: pid_t, name: String, error: AXError, windows: [LiveWindow]) {
        inFlight.remove(pid)
        guard error == .success else {
            // Keep whatever we knew before; log each failing app once.
            if reportedFailures.insert(pid).inserted {
                Log.write("window list unavailable for \(name): AX error \(error.rawValue)")
            }
            return
        }
        reportedFailures.remove(pid)
        onUpdate?(pid, windows)
    }

    private nonisolated static func read(pid: pid_t, appName: String) -> (AXError, [LiveWindow]) {
        let (error, elements) = AXLive.windows(pid: pid, timeout: 1)
        let windows = elements.enumerated().compactMap { index, element -> LiveWindow? in
            guard let frame = AXLive.frame(element) else { return nil }
            return LiveWindow(
                candidate: WindowCandidate(
                    pid: pid,
                    title: AXLive.string(element, "AXTitle") ?? "",
                    frame: frame,
                    hasCloseButton: AXLive.canClose(element),
                    orderInApp: index
                ),
                element: element,
                appName: appName,
                indexInApp: index
            )
        }
        return (error, windows)
    }
}
