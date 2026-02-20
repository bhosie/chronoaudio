// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChronoAudio",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ChronoAudio",
            path: "Sources/ChronoAudio",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "ChronoAudioTests",
            dependencies: ["ChronoAudio"],
            path: "Tests/ChronoAudioTests"
        )
    ]
)
