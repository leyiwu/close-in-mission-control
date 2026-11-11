import CoreGraphics

/// A real application window, described by what we can compare against a thumbnail.
public struct WindowCandidate: Equatable, Sendable {
    public var pid: Int32
    public var title: String
    public var frame: CGRect
    /// False when there is no close button or it is disabled (a dialog is blocking the window).
    public var hasCloseButton: Bool
    /// Position in the owning app's window list, front to back.
    public var orderInApp: Int

    public init(pid: Int32, title: String, frame: CGRect, hasCloseButton: Bool, orderInApp: Int = 0) {
        self.pid = pid
        self.title = title
        self.frame = frame
        self.hasCloseButton = hasCloseButton
        self.orderInApp = orderInApp
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

        // Title matches are looked up among all windows, closable or not: if this
        // thumbnail's own window cannot be closed, we must not fall back to another one.
        // An exact title wins; otherwise accept a window whose title is the thumbnail's
        // label plus an app suffix (Chrome: "New Tab" vs "New Tab - Google Chrome - Me").
        var titled = candidates.indices.filter { titleMatches(shown: thumbnail.title, real: candidates[$0].title) }
        if titled.isEmpty {
            titled = candidates.indices.filter { titleHasSuffix(shown: thumbnail.title, real: candidates[$0].title) }
        }
        if !titled.isEmpty {
            let hits = titled.filter { aspectMatches(thumbnail.frame, candidates[$0].frame, tolerance: aspectTolerance) }
            if hits.isEmpty { return nil }
            if hits.count == 1 { return candidates[hits[0]].hasCloseButton ? hits[0] : nil }
            return matchByOrder(thumbnail, hits: hits, in: candidates, allThumbnails: allThumbnails, tolerance: aspectTolerance)
        }

        let others = allThumbnails.filter { $0 != thumbnail }
        let unclaimed = closable.filter { index in
            let window = candidates[index]
            guard aspectMatches(thumbnail.frame, window.frame, tolerance: fallbackAspectTolerance) else { return false }
            return !others.contains { other in
                (titleMatches(shown: other.title, real: window.title)
                    || titleHasSuffix(shown: other.title, real: window.title))
                    && aspectMatches(other.frame, window.frame, tolerance: aspectTolerance)
            }
        }
        return unclaimed.count == 1 ? unclaimed[0] : nil
    }

    /// Several windows share this thumbnail's title and shape. Mission Control lists
    /// thumbnails front to back, and an app lists its own windows front to back
    /// (observed on macOS 26.6), so within one app the n-th look-alike thumbnail is the
    /// n-th look-alike window. Anything that breaks that one-to-one pairing returns nil.
    private static func matchByOrder(
        _ thumbnail: Thumbnail, hits: [Int], in candidates: [WindowCandidate],
        allThumbnails: [Thumbnail], tolerance: Double
    ) -> Int? {
        let first = candidates[hits[0]]
        // Order is only comparable inside one app, and every window must be closable.
        guard hits.allSatisfy({ candidates[$0].pid == first.pid && candidates[$0].hasCloseButton }) else {
            return nil
        }
        let lookAlikes = allThumbnails.filter {
            $0.title == thumbnail.title && aspectMatches($0.frame, first.frame, tolerance: tolerance)
        }
        guard lookAlikes.count == hits.count, let position = lookAlikes.firstIndex(of: thumbnail) else {
            return nil
        }
        let ordered = hits.sorted { candidates[$0].orderInApp < candidates[$1].orderInApp }
        guard Set(ordered.map { candidates[$0].orderInApp }).count == ordered.count else { return nil }
        return ordered[position]
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

    /// True when the window's title is the thumbnail's label followed by " - something".
    static func titleHasSuffix(shown: String, real: String) -> Bool {
        guard !shown.isEmpty, real.count > shown.count, real.hasPrefix(shown) else { return false }
        let rest = real.dropFirst(shown.count)
        return [" - ", " — ", " – "].contains { rest.hasPrefix($0) }
    }

    public static func aspectMatches(_ a: CGRect, _ b: CGRect, tolerance: Double) -> Bool {
        guard a.height > 0, b.height > 0, b.width > 0 else { return false }
        let ra = a.width / a.height
        let rb = b.width / b.height
        return abs(ra - rb) / rb <= tolerance
    }
}
