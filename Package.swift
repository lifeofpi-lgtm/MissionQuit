// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MissionQuit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MissionQuit",
            path: "Sources/MissionQuit",
            linkerSettings: [
                .unsafeFlags(["-framework", "Cocoa"]),
                .unsafeFlags(["-framework", "ApplicationServices"]),
            ]
        )
    ]
)
