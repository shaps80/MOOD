// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlParticles",
    products: [
        .library(
            name: "PixlParticles",
            targets: ["PixlParticles"]
        )
    ],
    targets: [
        .target(
            name: "PixlParticles"
        ),
        .testTarget(
            name: "PixlParticlesTests",
            dependencies: ["PixlParticles"]
        )
    ],
    swiftLanguageModes: [.v6]
)
