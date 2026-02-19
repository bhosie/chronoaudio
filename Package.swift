// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuitarApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GuitarApp",
            path: "Sources/GuitarApp",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "GuitarAppTests",
            dependencies: ["GuitarApp"],
            path: "Tests/GuitarAppTests"
        )
    ]
)
