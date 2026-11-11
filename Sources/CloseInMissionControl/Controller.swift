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
    private var orderLogged = false
    private var targetThumbnail: Thumbnail?
    /// Thumbnails whose window we closed while Mission Control stayed open. Mission
    /// Control keeps showing them as empty slots, so they must never match a window.
    private var closedSlots: [Thumbnail] = []

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

        let onScreen = ThumbnailScanner.thumbnails(in: mc)
        guard settle.update(onScreen) else { return hideButton(note: "moving") }
        let thumbnails = onScreen.filter { !closedSlots.contains($0) }
        // Apps report incomplete window lists while Mission Control is still animating
        // (seen on macOS 26.6), so the list is read only once things have settled.
        if needsRefreshAfterSettle {
            needsRefreshAfterSettle = false
            refreshWindows()
        }

        // Diagnostic: does the Dock list thumbnails in the same order as each app lists
        // its windows? If so, order can tell apart windows with the same title and shape.
        if !orderLogged, !windows.isEmpty, Date().timeIntervalSince(lastRefresh) > 0.5 {
            orderLogged = true
            let candidates = windows.map(\.candidate)
            let order = thumbnails.map { thumbnail -> String in
                guard let i = WindowMatcher.match(thumbnail, in: candidates, allThumbnails: thumbnails) else {
                    return "?\"\(thumbnail.title)\""
                }
                return "\(windows[i].appName)#\(windows[i].indexInApp)\"\(thumbnail.title)\""
            }
            Log.write("order: \(order.joined(separator: " | "))")
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
        targetThumbnail = hovered
        note("hover \"\(hovered.title)\" -> \(windows[index].appName)#\(windows[index].indexInApp); button shown")
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
        orderLogged = false
        closedSlots = []
        schedule(Self.idleInterval)
    }

    private func hideButton(note text: String) {
        target = nil
        targetThumbnail = nil
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

    /// If the app answered the close with a prompt (unsaved changes, running process),
    /// the prompt would otherwise float over Mission Control with its window nowhere in
    /// sight. Switch to that window instead, the same way a click on its thumbnail would.
    private func showBlockingDialog(for window: LiveWindow, slot: Thumbnail) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350)) // give the app time to put the prompt up
            guard self.active, AXLive.isBlockedFromClosing(window.element) else { return }
            self.closedSlots.removeAll { $0 == slot } // it did not close after all
            guard let dock = self.dock else { return }
            let pressed = AXLive.pressThumbnail(dock: dock, title: slot.title, frame: slot.frame)
            Log.write("close was stopped by a dialog; switching to \"\(slot.title)\": \(pressed ? "ok" : "thumbnail not found")")
        }
    }

    private func refreshWindows() {
        lastRefresh = Date()
        let running = directory.refresh()
        windows.removeAll { !running.contains($0.candidate.pid) }
    }

    private func closeTarget() {
        guard let target else { return }
        let slot = targetThumbnail
        Log.write("click: closing \"\(target.candidate.title)\" (\(target.appName))")
        AXUIElementSetMessagingTimeout(target.element, 1)
        let error = AXLive.pressCloseButton(target.element)
        Log.write("close result: \(error == .success ? "success" : "AX error \(error.rawValue)")")
        hideButton(note: "after click")
        settle.reset()
        windows.removeAll { CFEqual($0.element, target.element) }
        if error == .success, let slot {
            closedSlots.append(slot)
            showBlockingDialog(for: target, slot: slot)
        }
        needsRefreshAfterSettle = true
    }
}
