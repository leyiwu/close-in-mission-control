import CoreGraphics

/// One window thumbnail as Mission Control exposes it: a title and a frame, nothing else.
public struct Thumbnail: Equatable, Sendable {
    public var title: String
    /// Global AX coordinates (top-left origin).
    public var frame: CGRect

    public init(title: String, frame: CGRect) {
        self.title = title
        self.frame = frame
    }
}

public enum ThumbnailScanner {
    /// Verified on macOS 26.6: thumbnails are `AXButton` children of the group with
    /// `AXIdentifier == "mc.windows"` (one such group per display).
    public static func thumbnails(in root: AXSnapshot) -> [Thumbnail] {
        var found: [Thumbnail] = []
        collect(root, into: &found)
        return found
    }

    private static func collect(_ node: AXSnapshot, into found: inout [Thumbnail]) {
        if node.identifier == "mc.windows" {
            for child in node.children where child.role == "AXButton" {
                guard let frame = child.frame, frame.width > 0, frame.height > 0 else { continue }
                found.append(Thumbnail(title: child.title ?? "", frame: frame))
            }
            return
        }
        for child in node.children { collect(child, into: &found) }
    }
}

/// Reports "settled" once the full set of thumbnails has been identical for `required` ticks.
public struct SettleDetector: Sendable {
    public let required: Int
    private var last: [Thumbnail] = []
    private var stableTicks = 0

    public init(required: Int) { self.required = required }

    public mutating func update(_ thumbnails: [Thumbnail]) -> Bool {
        if thumbnails == last {
            stableTicks += 1
        } else {
            last = thumbnails
            stableTicks = 0
        }
        return !thumbnails.isEmpty && stableTicks >= required
    }

    public mutating func reset() {
        last = []
        stableTicks = 0
    }
}

public enum HoverResolver {
    /// The thumbnail under the pointer. If several overlap, the smallest wins.
    public static func hovered(at point: CGPoint, in thumbnails: [Thumbnail]) -> Thumbnail? {
        thumbnails
            .filter { $0.frame.contains(point) }
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }
}
