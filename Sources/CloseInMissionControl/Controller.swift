import AppKit
import CloseInMissionControlCore

/// Ties the pieces together: watch for Mission Control, find the hovered thumbnail,
/// show the × once things stop moving, close the matching window on click.
@MainActor
final class Controller {
    private static let idleInterval = 0.25   // waiting for Mission Control to open
    private static let activeInterval = 0.05 // tracking thumbnails while it is open
    private static let retryInterval = 0.3   // re-read window lists while a hover has no match

    private let isPermitted: () -> Bool
    private let overlay = Overlay()
    private let clicks = ClickInterceptor()
    private var needsRefreshAfterSettle = false
    private var timer: Timer?
    private var dock: AXUIElement?
    private var active = false
    private var settle = SettleDetector(required: 3)
    private var windows: [LiveWindow] = []
    private let directory = WindowDirectory()
    private var lastRefresh = Date.distantPast
    private var target: LiveWindow?
    private var lastNote = ""

    init(isPermitted: @escaping () -> Bool) {
        self.isPermitted = isPermitted
        clicks.onClick = { [weak self] in self?.closeTarget() }
        directory.onUpdate = { [weak self] pid, fresh in
            guard let self else { return }
            let before = self.windows.count
            self.windows.removeAll { $0.candidate.pid == pid }
            self.windows += fresh
            if self.windows.count != before { Log.write("windows known: \(self.windows.count)") }
        }
    }

    func start() {
        Log.write("started; accessibility trusted=\(isPermitted())")
        schedule(Self.idleInterval)
    }

    private func schedule(_ interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard isPermitted() else { return leaveMissionControl() }
        if dock == nil { dock = AXLive.dockApplication() }
        guard let dock, let mc = AXLive.missionControl(dock: dock) else { return leaveMissionControl() }

        if !active {
            active = true
            Log.write("Mission Control opened")
            schedule(Self.activeInterval)
            _ = clicks.setEnabled(true)
            needsRefreshAfterSettle = true
        }

        let thumbnails = ThumbnailScanner.thumbnails(in: mc)
        guard settle.update(thumbnails) else { return hideButton(note: "moving") }
        // Apps report incomplete window lists while Mission Control is still animating
        // (seen on macOS 26.6), so the list is read only once things have settled.
        if needsRefreshAfterSettle {
            needsRefreshAfterSettle = false
            refreshWindows()
        }

        let mouse = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let pointer = CGPoint(x: mouse.x, y: primaryHeight - mouse.y)
        // The button straddles the thumbnail's corner, so half of it lies outside the
        // thumbnail. While the pointer is on the button, keep the current target.
        if target != nil, let rect = clicks.hotRect, rect.contains(pointer) {
            overlay.setHighlighted(true)
            return
        }
        guard let hovered = HoverResolver.hovered(at: pointer, in: thumbnails) else {
            return hideButton(note: "settled, \(thumbnails.count) thumbnails, none hovered")
        }

        guard let index = WindowMatcher.match(hovered, in: windows.map(\.candidate), allThumbnails: thumbnails) else {
            // Record which real windows have the same shape, to diagnose title mismatches.
            let sameShape = windows
                .filter { WindowMatcher.aspectMatches(hovered.frame, $0.candidate.frame, tolerance: 0.04) }
                .map { "\($0.appName):\"\($0.candidate.title)\"" }
            hideButton(note: "hover \"\(hovered.title)\": no unique window match; same-shape windows: \(sameShape)")
            if Date().timeIntervalSince(lastRefresh) > Self.retryInterval { refreshWindows() }
            return
        }

        target = windows[index]
        note("hover \"\(hovered.title)\" -> \(windows[index].appName); button shown")
        // Centred on the thumbnail's top-left corner.
        let corner = CGPoint(x: hovered.frame.minX - Overlay.size / 2, y: hovered.frame.minY - Overlay.size / 2)
        let hotRect = CGRect(origin: corner, size: CGSize(width: Overlay.size, height: Overlay.size))
        clicks.hotRect = hotRect
        overlay.setHighlighted(hotRect.contains(pointer))
        overlay.show(atAXTopLeft: corner)
    }

    private func leaveMissionControl() {
        guard active else { return }
        active = false
        Log.write("Mission Control closed")
        _ = clicks.setEnabled(false)
        hideButton(note: "")
        settle.reset()
        schedule(Self.idleInterval)
    }

    private func hideButton(note text: String) {
        target = nil
        clicks.hotRect = nil
        overlay.hide()
        note(text)
    }

    /// Logs state changes only, so the log stays small at 20 ticks per second.
    private func note(_ text: String) {
        guard text != lastNote else { return }
        lastNote = text
        if !text.isEmpty { Log.write(text) }
    }

    private func refreshWindows() {
        lastRefresh = Date()
        let running = directory.refresh()
        windows.removeAll { !running.contains($0.candidate.pid) }
    }

    private func closeTarget() {
        guard let target else { return }
        Log.write("click: closing \"\(target.candidate.title)\" (\(target.appName))")
        AXUIElementSetMessagingTimeout(target.element, 1)
        let error = AXLive.pressCloseButton(target.element)
        Log.write("close result: \(error == .success ? "success" : "AX error \(error.rawValue)")")
        hideButton(note: "after click")
        settle.reset()
        windows.removeAll { CFEqual($0.element, target.element) }
        needsRefreshAfterSettle = true
    }
}
