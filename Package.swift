// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenLock",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenLock",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags(["-framework", "AppKit"]),
                .unsafeFlags(["-framework", "ApplicationServices"]),
                .unsafeFlags(["-framework", "ServiceManagement"]),
            ]
        )
    ]
)
