import CoreGraphics
import Testing
@testable import CloseInMissionControlCore

@Suite struct AXSnapshotTests {
    let tree = AXSnapshot(role: "AXApplication", title: "Dock", children: [
        AXSnapshot(role: "AXList", children: [AXSnapshot(role: "AXDockItem", title: "Finder")]),
        AXSnapshot(role: "AXGroup", identifier: "mc", children: [
            AXSnapshot(
                role: "AXButton",
                title: "Memories",
                frame: CGRect(x: 880, y: 520, width: 1100, height: 660),
                actions: ["AXPress"]
            ),
        ]),
    ])

    @Test func findsNestedIdentifier() {
        #expect(tree.first(identifier: "mc")?.children.first?.title == "Memories")
    }

    @Test func missingIdentifierIsNil() {
        #expect(tree.first(identifier: "nope") == nil)
    }

    @Test func countsEveryNode() {
        #expect(tree.count == 5)
    }

    @Test func formatsOneIndentedLinePerNode() {
        let lines = tree.formatted().split(separator: "\n").map(String.init)
        #expect(lines.count == 5)
        #expect(lines[0] == "AXApplication title=\"Dock\"")
        #expect(lines[3] == "  AXGroup id=mc")
        #expect(lines[4] == "    AXButton title=\"Memories\" frame=(880,520 1100x660) actions=[AXPress]")
    }
}
