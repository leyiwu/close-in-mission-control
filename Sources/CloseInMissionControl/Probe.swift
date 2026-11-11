import AppKit
import CloseInMissionControlCore

/// Milestone 1 feasibility probe: writes what Accessibility exposes while Mission Control is open.
@MainActor
enum Probe {
    static var logsFolder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/CloseInMissionControl", isDirectory: true)
    }

    /// Returns the file written, or nil if the Dock could not be read.
    static func writeDump() throws -> URL? {
        guard let dock = AXLive.dockApplication() else { return nil }
        let dockTree = AXLive.snapshot(dock)

        var out: [String] = []
        out.append("Close in Mission Control AX probe")
        out.append("date: \(ISO8601DateFormatter().string(from: Date()))")
        out.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        out.append("accessibility trusted: \(AXLive.isTrusted)")
        out.append("dock has id=mc element (Mission Control open?): \(dockTree.first(identifier: "mc") != nil)")
        out.append("dock elements captured: \(dockTree.count)")

        // AX frames use a top-left origin on the primary display; AppKit uses bottom-left.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let mouse = NSEvent.mouseLocation
        out.append("mouse (AX coords): (\(Int(mouse.x)),\(Int(primaryHeight - mouse.y)))")
        for (index, screen) in NSScreen.screens.enumerated() {
            let f = screen.frame
            out.append("screen \(index): AppKit frame=(\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))) scale=\(screen.backingScaleFactor)")
        }

        out.append("\n=== Dock AX tree ===")
        out.append(dockTree.formatted())

        out.append("\n=== Application windows (for correlation) ===")
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let element = AXLive.application(pid: app.processIdentifier)
            let windows = AXLive.children(element, attribute: "AXWindows")
            out.append("\(app.localizedName ?? "?") [\(app.bundleIdentifier ?? "?")] pid=\(app.processIdentifier) windows=\(windows.count)")
            for window in windows {
                let snap = AXLive.snapshot(window, maxDepth: 0)
                let hasClose = snap.extraAttributes.contains("AXCloseButton")
                out.append("  " + snap.formatted() + " closeButton=\(hasClose)")
            }
        }

        try FileManager.default.createDirectory(at: logsFolder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let file = logsFolder.appendingPathComponent("ax-dump-\(stamp).txt")
        try out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
