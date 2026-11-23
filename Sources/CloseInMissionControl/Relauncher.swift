import AppKit

/// Starts a fresh copy of the app and quits the running one. Used only when the app has found
/// that it can no longer put windows on screen (see `WindowHealth`), because a restart is what
/// fixes that.
enum Relauncher {
    private static let flag = "--relaunched-at"
    /// A restart does not follow another one sooner than this, so a fault that a restart
    /// cannot fix does not turn into a loop.
    private static let minimumGap: TimeInterval = 120

    /// When this process was itself started by a relaunch, the time of that relaunch.
    static var lastRelaunch: Date? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count,
              let seconds = TimeInterval(args[index + 1]) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// A relaunched copy starts quietly, like a login item, instead of opening the welcome window.
    static var wasRelaunched: Bool { lastRelaunch != nil }

    @MainActor
    static func relaunch(reason: String) {
        if let last = lastRelaunch, Date().timeIntervalSince(last) < minimumGap {
            Log.write("relaunch skipped, the last one was \(Int(Date().timeIntervalSince(last))) s ago: \(reason)")
            return
        }
        Log.write("relaunching: \(reason)")
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // -n starts a new instance even though this one is still running.
        open.arguments = ["-n", Bundle.main.bundleURL.path, "--args", flag, String(Int(Date().timeIntervalSince1970))]
        do {
            try open.run()
        } catch {
            Log.write("relaunch failed: \(error.localizedDescription)")
            return
        }
        // Give the new copy a moment to start before this one goes away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NSApp.terminate(nil) }
    }
}
