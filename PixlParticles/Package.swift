// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlParticles",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PixlParticles",
            targets: ["PixlParticles"]
        ),
        .executable(
            name: "PixlParticlesUI",
            targets: ["PixlParticlesUI"]
        )
    ],
    targets: [
        .target(
            name: "PixlParticles"
        ),
        .executableTarget(
            name: "PixlParticlesUI",
            dependencies: ["PixlParticles"]
        )
    ],
    swiftLanguageModes: [.v6]
)
