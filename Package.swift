// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioPilot",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AudioPilot",
            path: "Sources/AudioPilot"
        )
    ]
)
