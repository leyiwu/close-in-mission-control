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
    ///
    /// Some apps label their thumbnail differently from the window's AX title (seen:
    /// Photos). When no window carries the thumbnail's title at all, we fall back to the
    /// one window of the same shape that no other thumbnail accounts for.
    ///
    /// - Parameter allThumbnails: every thumbnail on screen, used only by the fallback.
    public static func match(
        _ thumbnail: Thumbnail,
        in candidates: [WindowCandidate],
        allThumbnails: [Thumbnail] = [],
        aspectTolerance: Double = 0.04,
        fallbackAspectTolerance: Double = 0.015
    ) -> Int? {
        let closable = candidates.indices.filter { candidates[$0].hasCloseButton }

        let titled = closable.filter { titleMatches(shown: thumbnail.title, real: candidates[$0].title) }
        if !titled.isEmpty {
            let hits = titled.filter { aspectMatches(thumbnail.frame, candidates[$0].frame, tolerance: aspectTolerance) }
            return hits.count == 1 ? hits[0] : nil
        }

        let others = allThumbnails.filter { $0 != thumbnail }
        let unclaimed = closable.filter { index in
            let window = candidates[index]
            guard aspectMatches(thumbnail.frame, window.frame, tolerance: fallbackAspectTolerance) else { return false }
            return !others.contains { other in
                titleMatches(shown: other.title, real: window.title)
                    && aspectMatches(other.frame, window.frame, tolerance: aspectTolerance)
            }
        }
        return unclaimed.count == 1 ? unclaimed[0] : nil
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

    public static func aspectMatches(_ a: CGRect, _ b: CGRect, tolerance: Double) -> Bool {
        guard a.height > 0, b.height > 0, b.width > 0 else { return false }
        let ra = a.width / a.height
        let rb = b.width / b.height
        return abs(ra - rb) / rb <= tolerance
    }
}
