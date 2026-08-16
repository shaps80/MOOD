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
        ),
        .library(
            name: "PixlMetal",
            targets: ["PixlMetal"]
        )
    ],
    targets: [
        .target(
            name: "PixlParticles",
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .target(
            name: "PixlRenderer",
            dependencies: ["PixlParticles"],
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .target(
            name: "PixlMetal",
            dependencies: [
                "PixlParticles",
                "PixlRenderer",
            ],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .testTarget(
            name: "PixlParticlesTests",
            dependencies: ["PixlParticles"]
        ),
        .testTarget(
            name: "PixlRendererTests",
            dependencies: ["PixlRenderer"]
        )
    ],
    swiftLanguageModes: [.v6]
)

private func releaseCrossModuleOptimization() -> [SwiftSetting] {
    [
        .unsafeFlags(
            ["-cross-module-optimization"],
            .when(configuration: .release)
        )
    ]
}
