// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlGraphics",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../PixlPlatform")
    ],
    targets: [
        .executableTarget(
            name: "PixlGraphics",
            dependencies: [
                "PixlPlatform"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
