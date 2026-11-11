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

    @Test func lookAlikesInDifferentAppsAreAmbiguous() {
        let twin = Thumbnail(title: "Applications", frame: rect(100, 600, 466, 221))
        let windows = [window("Applications"), window("Applications", pid: 2)]
        #expect(WindowMatcher.match(thumb, in: windows, allThumbnails: [thumb, twin]) == nil)
    }

    // Two Finder windows on the same folder at the same size.
    @Test func lookAlikesInOneAppArePairedByOrder() {
        let front = Thumbnail(title: "Applications", frame: rect(871, 216, 466, 221))
        let back = Thumbnail(title: "Applications", frame: rect(100, 600, 466, 221))
        // Listed back-first on purpose: pairing must follow orderInApp, not array position.
        let windows = [
            WindowCandidate(pid: 1, title: "Applications", frame: rect(300, 160, 920, 436), hasCloseButton: true, orderInApp: 1),
            WindowCandidate(pid: 1, title: "Applications", frame: rect(275, 141, 920, 436), hasCloseButton: true, orderInApp: 0),
        ]
        #expect(WindowMatcher.match(front, in: windows, allThumbnails: [front, back]) == 1)
        #expect(WindowMatcher.match(back, in: windows, allThumbnails: [front, back]) == 0)
    }

    @Test func lookAlikesAreRefusedWhenCountsDisagree() {
        // Two windows but only one such thumbnail on screen: the pairing is unknown.
        let windows = [
            WindowCandidate(pid: 1, title: "Applications", frame: rect(300, 160, 920, 436), hasCloseButton: true, orderInApp: 1),
            WindowCandidate(pid: 1, title: "Applications", frame: rect(275, 141, 920, 436), hasCloseButton: true, orderInApp: 0),
        ]
        #expect(WindowMatcher.match(thumb, in: windows, allThumbnails: [thumb]) == nil)
    }

    @Test func lookAlikesAreRefusedWhenOneCannotBeClosed() {
        let twin = Thumbnail(title: "Applications", frame: rect(100, 600, 466, 221))
        let windows = [
            WindowCandidate(pid: 1, title: "Applications", frame: rect(300, 160, 920, 436), hasCloseButton: false, orderInApp: 1),
            WindowCandidate(pid: 1, title: "Applications", frame: rect(275, 141, 920, 436), hasCloseButton: true, orderInApp: 0),
        ]
        #expect(WindowMatcher.match(thumb, in: windows, allThumbnails: [thumb, twin]) == nil)
    }

    @Test func duplicateTitlesAreSeparatedByShape() {
        let tall = window("Applications", rect(0, 0, 400, 800))
        #expect(WindowMatcher.match(thumb, in: [tall, window("Applications")]) == 1)
    }

    @Test func windowWithoutCloseButtonIsIgnored() {
        #expect(WindowMatcher.match(thumb, in: [window("Applications", close: false)]) == nil)
    }

    // Mail with its "Add Account" dialog up: the window exists but cannot be closed.
    @Test func blockedWindowDoesNotFallBackToAnotherWindowOfTheSameShape() {
        let blocked = window("Applications", close: false)
        let bystander = window("Unrelated", pid: 2)
        #expect(WindowMatcher.match(thumb, in: [blocked, bystander], allThumbnails: [thumb]) == nil)
    }

    @Test func wrongShapeIsRejected() {
        #expect(WindowMatcher.match(thumb, in: [window("Applications", rect(0, 0, 500, 500))]) == nil)
    }

    // Photos labels its thumbnail "Memories" while the window itself has another title.
    @Test func differingTitleFallsBackToTheOnlyUnclaimedWindowOfThatShape() {
        let memories = Thumbnail(title: "Memories", frame: rect(844, 501, 608, 365))
        let photos = window("Photos", rect(100, 100, 1216, 730))
        let finder = window("Applications")
        let index = WindowMatcher.match(memories, in: [finder, photos], allThumbnails: [thumb, memories])
        #expect(index == 1)
    }

    @Test func fallbackSkipsWindowsThatAnotherThumbnailAccountsFor() {
        // Same shape as the Finder window, but that window belongs to the "Applications" thumbnail.
        let mystery = Thumbnail(title: "Mystery", frame: rect(0, 0, 233, 110.5))
        #expect(WindowMatcher.match(mystery, in: [window("Applications")], allThumbnails: [thumb, mystery]) == nil)
    }

    @Test func fallbackRefusesTwoCandidates() {
        let memories = Thumbnail(title: "Memories", frame: rect(844, 501, 608, 365))
        let a = window("Photos", rect(0, 0, 1216, 730))
        let b = window("Other", rect(0, 0, 608, 365), pid: 2)
        #expect(WindowMatcher.match(memories, in: [a, b], allThumbnails: [memories]) == nil)
    }

    @Test func fallbackIsNotUsedWhenATitleMatchesButShapeDoesNot() {
        let odd = window("Applications", rect(0, 0, 500, 500))
        let sameShape = window("Unrelated", pid: 2)
        #expect(WindowMatcher.match(thumb, in: [odd, sameShape], allThumbnails: [thumb]) == nil)
    }

    // Chrome: the thumbnail says "New Tab", the window "New Tab - Google Chrome - Me".
    @Test func appSuffixedTitlesMatchAndPairByOrder() {
        let front = Thumbnail(title: "New Tab", frame: rect(871, 216, 466, 221))
        let back = Thumbnail(title: "New Tab", frame: rect(100, 600, 466, 221))
        let windows = [
            WindowCandidate(pid: 7, title: "New Tab - Google Chrome - Me", frame: rect(0, 0, 920, 436), hasCloseButton: true, orderInApp: 0),
            WindowCandidate(pid: 7, title: "New Tab - Google Chrome - Me", frame: rect(20, 20, 920, 436), hasCloseButton: true, orderInApp: 1),
            WindowCandidate(pid: 9, title: "Sticky", frame: rect(0, 0, 920, 436), hasCloseButton: true),
        ]
        #expect(WindowMatcher.match(front, in: windows, allThumbnails: [front, back]) == 0)
        #expect(WindowMatcher.match(back, in: windows, allThumbnails: [front, back]) == 1)
    }

    @Test func exactTitleBeatsSuffixedTitle() {
        let windows = [window("Applications - Something", pid: 2), window("Applications")]
        #expect(WindowMatcher.match(thumb, in: windows, allThumbnails: [thumb]) == 1)
    }

    @Test func suffixNeedsASeparator() {
        #expect(WindowMatcher.titleHasSuffix(shown: "New Tab", real: "New Tab - Google Chrome"))
        #expect(!WindowMatcher.titleHasSuffix(shown: "New Tab", real: "New Tabs"))
        #expect(!WindowMatcher.titleHasSuffix(shown: "New Tab", real: "New Tab"))
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
