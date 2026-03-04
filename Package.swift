// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PulseMon",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PulseMon",
            path: "PulseMon",
            linkerSettings: [
                .unsafeFlags(["-framework", "AppKit"]),
                .linkedLibrary("proc", .when(platforms: [.macOS])),
            ]
        ),
    ]
)
