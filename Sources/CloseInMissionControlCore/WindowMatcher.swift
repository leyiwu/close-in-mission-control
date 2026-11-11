import CoreGraphics

/// A real application window, described by what we can compare against a thumbnail.
public struct WindowCandidate: Equatable, Sendable {
    public var pid: Int32
    public var title: String
    public var frame: CGRect
    public var hasCloseButton: Bool

    public init(pid: Int32, title: String, frame: CGRect, hasCloseButton: Bool) {
        self.pid = pid
        self.title = title
        self.frame = frame
        self.hasCloseButton = hasCloseButton
    }
}

public enum WindowMatcher {
    /// Index of the single window that this thumbnail represents, or nil.
    ///
    /// Mission Control gives no app name or window id, so we match on title and aspect
    /// ratio (thumbnails are uniformly scaled). Anything other than exactly one match
    /// returns nil: closing the wrong window is worse than showing no button.
    public static func match(
        _ thumbnail: Thumbnail,
        in candidates: [WindowCandidate],
        aspectTolerance: Double = 0.04
    ) -> Int? {
        let hits = candidates.indices.filter { index in
            let window = candidates[index]
            return window.hasCloseButton
                && titleMatches(shown: thumbnail.title, real: window.title)
                && aspectMatches(thumbnail.frame, window.frame, tolerance: aspectTolerance)
        }
        return hits.count == 1 ? hits[0] : nil
    }

    /// Mission Control shortens long titles with "…" in the middle or at the end.
    static func titleMatches(shown: String, real: String) -> Bool {
        if shown.isEmpty || real.isEmpty { return false }
        if shown == real { return true }
        guard shown.contains("…") else { return false }
        let parts = shown.components(separatedBy: "…")
        guard let head = parts.first, let tail = parts.last, !(head.isEmpty && tail.isEmpty) else { return false }
        return real.hasPrefix(head) && real.hasSuffix(tail) && real.count >= head.count + tail.count
    }

    static func aspectMatches(_ a: CGRect, _ b: CGRect, tolerance: Double) -> Bool {
        guard a.height > 0, b.height > 0, b.width > 0 else { return false }
        let ra = a.width / a.height
        let rb = b.width / b.height
        return abs(ra - rb) / rb <= tolerance
    }
}
