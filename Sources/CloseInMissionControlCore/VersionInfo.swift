import Foundation

/// Which build is running, read from the app's Info.plist: the version, whether it is a
/// release or was built from source, and for source builds the git commit it came from.
/// `scripts/build-app.sh` stamps `BuildKind` and `GitCommit`; releases come from
/// `scripts/release.sh`, which marks them `release`.
public struct VersionInfo: Equatable, Sendable {
    public var version: String
    public var build: String
    public var isDevelopmentBuild: Bool
    /// Short commit hash; a trailing "+" means uncommitted changes. Source builds only.
    public var commit: String?

    public init(version: String, build: String, isDevelopmentBuild: Bool, commit: String? = nil) {
        self.version = version
        self.build = build
        self.isDevelopmentBuild = isDevelopmentBuild
        self.commit = commit
    }

    public init(infoDictionary: [String: Any]?) {
        let info = infoDictionary ?? [:]
        version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        build = info["CFBundleVersion"] as? String ?? "?"
        // Anything not explicitly stamped as a release is treated as a development build.
        isDevelopmentBuild = (info["BuildKind"] as? String) != "release"
        commit = info["GitCommit"] as? String
    }

    /// The line shown in the menu, kept short so it does not widen the menu. A release is
    /// just its version; a build from source adds the commit it came from (or "dev").
    /// `versionWord` is the localized word for "Version"; the rest is language-neutral.
    public func menuTitle(versionWord: String = "Version") -> String {
        guard isDevelopmentBuild else { return "\(versionWord) \(version)" }
        return "\(versionWord) \(version) · \(commit ?? "dev")"
    }

    /// One line for the log, with the build number too.
    public var logSummary: String {
        let kind = isDevelopmentBuild ? "development" : "release"
        return "\(version) (build \(build), \(kind)\(commit.map { ", commit \($0)" } ?? ""))"
    }

    /// A release's own notes; a development build has no tag of its own, so the list.
    public var releaseNotesURL: URL {
        let base = "https://github.com/leyiwu/close-in-mission-control/releases"
        return URL(string: isDevelopmentBuild ? base : "\(base)/tag/v\(version)")!
    }
}
