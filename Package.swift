// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CloseInMissionControl",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic and thin Accessibility wrappers. No UI.
        .target(name: "CloseInMissionControlCore"),
        // Menu-bar app shell.
        .executableTarget(name: "CloseInMissionControl", dependencies: ["CloseInMissionControlCore"]),
        .testTarget(name: "CloseInMissionControlCoreTests", dependencies: ["CloseInMissionControlCore"]),
    ]
)
