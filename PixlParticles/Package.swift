// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlParticles",
    platforms: [
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .iOS(.v17),
        .visionOS(.v1)
    ],
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
