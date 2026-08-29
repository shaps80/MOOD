// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Game",
    platforms: [
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .iOS(.v17),
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
