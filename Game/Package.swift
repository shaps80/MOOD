// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Game",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../Pixl"),
        .package(path: "../PixlPlatform")
    ],
    targets: [
        .executableTarget(
            name: "Game",
            dependencies: ["Pixl"],
            plugins: [
                .plugin(name: "PixlShaderPlugin", package: "PixlPlatform")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
