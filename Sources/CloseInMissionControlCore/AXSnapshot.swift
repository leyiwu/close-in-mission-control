import CoreGraphics

/// An immutable copy of one Accessibility element and its subtree.
///
/// Everything above the live AX layer works on snapshots, so it can be
/// unit-tested with hand-built trees and no Accessibility permission.
public struct AXSnapshot: Equatable, Sendable {
    public var role: String?
    public var subrole: String?
    public var identifier: String?
    public var title: String?
    public var label: String?
    /// Global screen coordinates, origin at the top-left of the primary display.
    public var frame: CGRect?
    public var actions: [String]
    /// Attribute names beyond the common ones; recorded for discovery only.
    public var extraAttributes: [String]
    public var children: [AXSnapshot]

    public init(
        role: String? = nil,
        subrole: String? = nil,
        identifier: String? = nil,
        title: String? = nil,
        label: String? = nil,
        frame: CGRect? = nil,
        actions: [String] = [],
        extraAttributes: [String] = [],
        children: [AXSnapshot] = []
    ) {
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
        self.label = label
        self.frame = frame
        self.actions = actions
        self.extraAttributes = extraAttributes
        self.children = children
    }

    /// Depth-first search for the first element with the given AXIdentifier.
    public func first(identifier wanted: String) -> AXSnapshot? {
        if identifier == wanted { return self }
        for child in children {
            if let hit = child.first(identifier: wanted) { return hit }
        }
        return nil
    }

    /// Total number of elements in this subtree, including the root.
    public var count: Int {
        children.reduce(1) { $0 + $1.count }
    }

    /// Indented, one-line-per-element text used by the feasibility probe.
    public func formatted(indent: Int = 0) -> String {
        var parts: [String] = [role ?? "?"]
        if let subrole { parts.append("subrole=\(subrole)") }
        if let identifier { parts.append("id=\(identifier)") }
        if let title { parts.append("title=\"\(title)\"") }
        if let label { parts.append("label=\"\(label)\"") }
        if let f = frame {
            parts.append("frame=(\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height)))")
        }
        if !actions.isEmpty { parts.append("actions=[\(actions.joined(separator: ","))]") }
        if !extraAttributes.isEmpty { parts.append("attrs=[\(extraAttributes.joined(separator: ","))]") }
        let line = String(repeating: "  ", count: indent) + parts.joined(separator: " ")
        return ([line] + children.map { $0.formatted(indent: indent + 1) }).joined(separator: "\n")
    }
}
