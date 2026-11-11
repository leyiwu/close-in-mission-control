import CoreGraphics
import Testing
@testable import CloseInMissionControlCore

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
}

@Suite struct ThumbnailScannerTests {
    // Shape taken from a real macOS 26.6 dump.
    let mc = AXSnapshot(role: "AXGroup", identifier: "mc", children: [
        AXSnapshot(role: "AXGroup", identifier: "mc.display", children: [
            AXSnapshot(role: "AXGroup", identifier: "mc.windows", children: [
                AXSnapshot(role: "AXButton", title: "Applications", frame: rect(871, 216, 466, 221)),
                AXSnapshot(role: "AXButton", title: "Memories", frame: rect(844, 501, 608, 365)),
                AXSnapshot(role: "AXButton", title: "No frame"),
                AXSnapshot(role: "AXGroup", title: "Not a button", frame: rect(0, 0, 10, 10)),
            ]),
            AXSnapshot(role: "AXGroup", identifier: "mc.spaces", children: [
                AXSnapshot(role: "AXButton", title: "Desktop", frame: rect(326, 46, 138, 90)),
            ]),
        ]),
    ])

    @Test func onlyWindowButtonsWithFrames() {
        #expect(ThumbnailScanner.thumbnails(in: mc).map(\.title) == ["Applications", "Memories"])
    }

    @Test func noMissionControlMeansNoThumbnails() {
        #expect(ThumbnailScanner.thumbnails(in: AXSnapshot(role: "AXApplication")).isEmpty)
    }
}

@Suite struct SettleDetectorTests {
    let a = [Thumbnail(title: "A", frame: rect(0, 0, 100, 50))]
    let moved = [Thumbnail(title: "A", frame: rect(5, 0, 100, 50))]

    @Test func settlesAfterRequiredIdenticalTicks() {
        var detector = SettleDetector(required: 2)
        #expect(detector.update(a) == false)
        #expect(detector.update(a) == false)
        #expect(detector.update(a) == true)
    }

    @Test func movementRestartsTheCount() {
        var detector = SettleDetector(required: 1)
        _ = detector.update(a)
        #expect(detector.update(a) == true)
        #expect(detector.update(moved) == false)
        #expect(detector.update(moved) == true)
    }

    @Test func emptyNeverSettles() {
        var detector = SettleDetector(required: 0)
        #expect(detector.update([]) == false)
        #expect(detector.update([]) == false)
    }
}

@Suite struct HoverResolverTests {
    let big = Thumbnail(title: "Big", frame: rect(0, 0, 400, 300))
    let small = Thumbnail(title: "Small", frame: rect(50, 50, 100, 100))

    @Test func pointInsideOne() {
        #expect(HoverResolver.hovered(at: CGPoint(x: 300, y: 200), in: [big, small]) == big)
    }

    @Test func overlapPrefersSmallest() {
        #expect(HoverResolver.hovered(at: CGPoint(x: 60, y: 60), in: [big, small]) == small)
    }

    @Test func pointOutsideAll() {
        #expect(HoverResolver.hovered(at: CGPoint(x: 900, y: 900), in: [big, small]) == nil)
    }
}

@Suite struct WindowMatcherTests {
    let thumb = Thumbnail(title: "Applications", frame: rect(871, 216, 466, 221))

    func window(_ title: String, _ frame: CGRect = rect(275, 141, 920, 436), close: Bool = true, pid: Int32 = 1) -> WindowCandidate {
        WindowCandidate(pid: pid, title: title, frame: frame, hasCloseButton: close)
    }

    @Test func uniqueTitleAndAspectMatches() {
        #expect(WindowMatcher.match(thumb, in: [window("Other"), window("Applications")]) == 1)
    }

    @Test func duplicateTitlesWithSameShapeAreAmbiguous() {
        #expect(WindowMatcher.match(thumb, in: [window("Applications"), window("Applications", pid: 2)]) == nil)
    }

    @Test func duplicateTitlesAreSeparatedByShape() {
        let tall = window("Applications", rect(0, 0, 400, 800))
        #expect(WindowMatcher.match(thumb, in: [tall, window("Applications")]) == 1)
    }

    @Test func windowWithoutCloseButtonIsIgnored() {
        #expect(WindowMatcher.match(thumb, in: [window("Applications", close: false)]) == nil)
    }

    @Test func wrongShapeIsRejected() {
        #expect(WindowMatcher.match(thumb, in: [window("Applications", rect(0, 0, 500, 500))]) == nil)
    }

    @Test func truncatedTitles() {
        #expect(WindowMatcher.titleMatches(shown: "Can Jackie…YouTube", real: "Can Jackie Chan play - YouTube"))
        #expect(WindowMatcher.titleMatches(shown: "- Skims pants…", real: "- Skims pants and more"))
        #expect(WindowMatcher.titleMatches(shown: "- Skims pants…", real: "- Skims pants…"))
        #expect(!WindowMatcher.titleMatches(shown: "Can Jackie…YouTube", real: "Something else - YouTube"))
        #expect(!WindowMatcher.titleMatches(shown: "…", real: "Anything"))
        #expect(!WindowMatcher.titleMatches(shown: "", real: ""))
    }
}
