// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Game",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../Pixl")
    ],
    targets: [
        .executableTarget(
            name: "Game",
            dependencies: ["Pixl"]
        )
    ],
    swiftLanguageModes: [.v6]
)
