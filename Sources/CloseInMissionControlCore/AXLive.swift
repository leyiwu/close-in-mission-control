import AppKit
import ApplicationServices

/// The only place that talks to the live Accessibility API.
/// All calls are public, documented AX functions.
public enum AXLive {
    /// Attributes already captured as snapshot fields; not repeated in `extraAttributes`.
    private static let commonAttributes: Set<String> = [
        "AXRole", "AXSubrole", "AXIdentifier", "AXTitle", "AXDescription",
        "AXPosition", "AXSize", "AXFrame", "AXChildren", "AXParent",
        "AXRoleDescription", "AXTopLevelUIElement", "AXWindow",
    ]

    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// The Dock process draws Mission Control. (Undocumented dependency: see DEPENDENCIES.md.)
    public static func dockApplication() -> AXUIElement? {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        return application(pid: dock.processIdentifier)
    }

    public static func application(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        // Never let a hung app stall us for the default 6 s.
        AXUIElementSetMessagingTimeout(element, 0.5)
        return element
    }

    /// Copies an element and its subtree, bounded in depth and total size.
    /// - Parameters:
    ///   - detail: false reads only role, identifier, title and frame (cheap enough to poll).
    ///   - skipping: subtrees whose AXIdentifier is listed are recorded but not descended into.
    public static func snapshot(
        _ element: AXUIElement,
        maxDepth: Int = 14,
        maxNodes: Int = 4000,
        detail: Bool = true,
        skipping: Set<String> = []
    ) -> AXSnapshot {
        var budget = maxNodes
        return snapshot(element, depth: 0, maxDepth: maxDepth, budget: &budget, detail: detail, skipping: skipping)
    }

    private static func snapshot(
        _ element: AXUIElement, depth: Int, maxDepth: Int, budget: inout Int, detail: Bool, skipping: Set<String>
    ) -> AXSnapshot {
        budget -= 1
        var node = AXSnapshot(
            role: string(element, "AXRole"),
            identifier: string(element, "AXIdentifier"),
            title: string(element, "AXTitle"),
            frame: frame(element)
        )
        if detail {
            node.subrole = string(element, "AXSubrole")
            node.label = string(element, "AXDescription")
            node.actions = actionNames(element)
            node.extraAttributes = attributeNames(element).filter { !commonAttributes.contains($0) }
        }
        if let id = node.identifier, skipping.contains(id) { return node }
        guard depth < maxDepth else { return node }
        for child in children(element) {
            guard budget > 0 else { break }
            node.children.append(snapshot(
                child, depth: depth + 1, maxDepth: maxDepth, budget: &budget, detail: detail, skipping: skipping
            ))
        }
        return node
    }

    /// A light snapshot of the Mission Control subtree, or nil when Mission Control is not open.
    public static func missionControl(dock: AXUIElement) -> AXSnapshot? {
        guard let mc = children(dock).first(where: { string($0, "AXIdentifier") == "mc" }) else { return nil }
        return snapshot(mc, maxDepth: 4, maxNodes: 300, detail: false, skipping: ["mc.spaces"])
    }

    /// An app's windows on the current Space, with the raw AX error for diagnostics.
    public static func windows(pid: pid_t, timeout: Float) -> (error: AXError, windows: [AXUIElement]) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        var ref: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, "AXWindows" as CFString, &ref)
        return (error, (ref as? [AXUIElement]) ?? [])
    }

    /// True when the window has a close button and that button is enabled, i.e. the red
    /// button in its title bar is live. The button's own state is the only test: an app
    /// disables it while something (a sign-in prompt, a sheet) blocks closing, and
    /// pressing a disabled button does nothing.
    public static func canClose(_ window: AXUIElement) -> Bool {
        guard let ref = value(window, "AXCloseButton"), CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            return false
        }
        // swiftlint:disable:next force_cast
        let button = ref as! AXUIElement
        if let enabled = value(button, "AXEnabled") as? Bool, !enabled { return false }
        return true
    }

    /// Presses the window's own close button, exactly as a click on the red button would.
    public static func pressCloseButton(_ window: AXUIElement) -> AXError {
        var ref: CFTypeRef?
        let lookup = AXUIElementCopyAttributeValue(window, "AXCloseButton" as CFString, &ref)
        guard lookup == .success, let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return lookup }
        // swiftlint:disable:next force_cast
        return AXUIElementPerformAction(ref as! AXUIElement, "AXPress" as CFString)
    }

    public static func children(_ element: AXUIElement, attribute: String = "AXChildren") -> [AXUIElement] {
        (value(element, attribute) as? [AXUIElement]) ?? []
    }

    public static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        guard let text = value(element, attribute) as? String, !text.isEmpty else { return nil }
        return text
    }

    public static func frame(_ element: AXUIElement) -> CGRect? {
        guard let origin: CGPoint = axValue(element, "AXPosition", .cgPoint),
              let size: CGSize = axValue(element, "AXSize", .cgSize)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return nil }
        return ref
    }

    private static func axValue<T>(_ element: AXUIElement, _ attribute: String, _ type: AXValueType) -> T? {
        guard let ref = value(element, attribute), CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(ref as! AXValue, type, pointer) else { return nil }
        return pointer.pointee
    }

    private static func attributeNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    private static func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }
}
