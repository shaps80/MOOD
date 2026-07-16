// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Game",
    platforms: [
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16),
        .iOS(.v16),
        .visionOS(.v1)
    ],
    dependencies: [
        .package(path: "../Pixl"),
    ],
    targets: [
        .executableTarget(
            name: "Game",
            dependencies: ["Pixl"]
        )
    ],
    swiftLanguageModes: [.v6]
)
