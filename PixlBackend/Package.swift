// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlBackend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PixlBackend",
            targets: ["PixlBackend"]
        ),
        .library(
            name: "PixlMetalBackend",
            targets: ["PixlMetalBackend"]
        ),
    ],
    targets: [
        .target(name: "PixlBackend"),
        .target(
            name: "PixlMetalBackend",
            dependencies: ["PixlBackend"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
