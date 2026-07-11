// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlGraphics",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../PixlBackend")
    ],
    targets: [
        .executableTarget(
            name: "PixlGraphics",
            dependencies: [
                "PixlBackend"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
