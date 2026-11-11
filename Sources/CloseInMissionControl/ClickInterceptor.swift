import AppKit

/// Catches the click on the × before Mission Control sees it.
///
/// Verified on macOS 26.6: while Mission Control is open, clicks never reach another
/// app's window, even one drawn on top (DEPENDENCIES.md #5). A `CGEventTap` (public API,
/// covered by the Accessibility permission) is the only way to receive the click.
/// The tap is enabled only while Mission Control is open and swallows only left clicks
/// that begin inside `hotRect`; every other event passes through untouched.
@MainActor
final class ClickInterceptor {
    /// Button area in global top-left coordinates (the same space AX and CGEvent use).
    var hotRect: CGRect?
    var onClick: (() -> Void)?
    private var tap: CFMachPort?
    private var pressBeganInside = false

    /// Returns false if the tap could not be created.
    func setEnabled(_ enabled: Bool) -> Bool {
        if tap == nil {
            guard enabled else { return true }
            tap = makeTap()
        }
        guard let tap else { return false }
        CGEvent.tapEnable(tap: tap, enable: enabled)
        if !enabled {
            hotRect = nil
            pressBeganInside = false
        }
        return true
    }

    private func makeTap() -> CFMachPort? {
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let location = event.location
            let swallow = MainActor.assumeIsolated {
                Unmanaged<ClickInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                    .handle(type: type, location: location)
            }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        // Earliest tap point first, so we run before the Dock's own handling.
        for location in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap] {
            if let port = CGEvent.tapCreate(
                tap: location, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: refcon
            ) {
                let source = CFMachPortCreateRunLoopSource(nil, port, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                Log.write("event tap created at \(location == .cghidEventTap ? "HID" : "session") level")
                return port
            }
        }
        Log.write("event tap could not be created")
        return nil
    }

    /// Returns true if the event should be swallowed.
    private func handle(type: CGEventType, location: CGPoint) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .leftMouseDown:
            pressBeganInside = hotRect?.contains(location) ?? false
            return pressBeganInside
        case .leftMouseUp:
            guard pressBeganInside else { return false }
            pressBeganInside = false
            if hotRect?.contains(location) ?? false { onClick?() }
            return true
        default:
            return false
        }
    }
}
