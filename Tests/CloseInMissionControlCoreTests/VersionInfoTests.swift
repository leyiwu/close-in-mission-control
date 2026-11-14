import Testing
@testable import CloseInMissionControlCore

@Suite struct VersionInfoTests {
    let release: [String: Any] = [
        "CFBundleShortVersionString": "0.1.5", "CFBundleVersion": "6", "BuildKind": "release",
    ]
    let development: [String: Any] = [
        "CFBundleShortVersionString": "0.1.5", "CFBundleVersion": "6",
        "BuildKind": "dev", "GitCommit": "2969ed0+",
    ]

    @Test func releaseShowsOnlyTheVersion() {
        let info = VersionInfo(infoDictionary: release)
        #expect(info.menuTitle() == "Version 0.1.5")
        #expect(!info.isDevelopmentBuild)
    }

    @Test func theWordForVersionCanBeLocalized() {
        #expect(VersionInfo(infoDictionary: release).menuTitle(versionWord: "版本") == "版本 0.1.5")
        #expect(VersionInfo(infoDictionary: development).menuTitle(versionWord: "版本") == "版本 0.1.5 · 2969ed0+")
    }

    @Test func developmentBuildShowsTheCommit() {
        #expect(VersionInfo(infoDictionary: development).menuTitle() == "Version 0.1.5 · 2969ed0+")
    }

    @Test func developmentBuildWithoutACommit() {
        var info = development
        info["GitCommit"] = nil
        #expect(VersionInfo(infoDictionary: info).menuTitle() == "Version 0.1.5 · dev")
    }

    @Test func anUnstampedBuildCountsAsDevelopment() {
        let info = VersionInfo(infoDictionary: ["CFBundleShortVersionString": "0.1.5"])
        #expect(info.isDevelopmentBuild)
        #expect(info.build == "?")
    }

    @Test func missingInfoStillProducesATitle() {
        #expect(VersionInfo(infoDictionary: nil).menuTitle() == "Version unknown · dev")
    }

    @Test func releaseNotesPointAtTheTagOrTheList() {
        #expect(VersionInfo(infoDictionary: release).releaseNotesURL.absoluteString
            == "https://github.com/leyiwu/close-in-mission-control/releases/tag/v0.1.5")
        #expect(VersionInfo(infoDictionary: development).releaseNotesURL.absoluteString
            == "https://github.com/leyiwu/close-in-mission-control/releases")
    }

    @Test func logLineHasTheBuildNumberAndKind() {
        #expect(VersionInfo(infoDictionary: release).logSummary == "0.1.5 (build 6, release)")
        #expect(VersionInfo(infoDictionary: development).logSummary == "0.1.5 (build 6, development, commit 2969ed0+)")
    }
}
