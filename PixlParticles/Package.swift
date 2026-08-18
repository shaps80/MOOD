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
        ),
        .library(
            name: "PixlEditorSupport",
            targets: ["PixlEditorSupport"]
        ),
        .library(
            name: "PixlEditorSupportMetal",
            targets: ["PixlEditorSupportMetal"]
        )
    ],
    dependencies: [
        .package(path: "../PixlMath")
    ],
    targets: [
        .target(
            name: "PixlParticles",
            dependencies: ["PixlRenderer"],
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .target(
            name: "PixlRenderer",
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .target(
            name: "PixlMetal",
            dependencies: ["PixlRenderer"],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .target(
            name: "PixlEditorSupport",
            dependencies: [
                "PixlRenderer",
                .product(name: "PixlMath", package: "PixlMath")
            ],
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .target(
            name: "PixlEditorSupportMetal",
            dependencies: ["PixlEditorSupport", "PixlMetal"],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: releaseCrossModuleOptimization()
        ),
        .testTarget(
            name: "PixlParticlesTests",
            dependencies: ["PixlParticles", "PixlRenderer"]
        ),
        .testTarget(
            name: "PixlRendererTests",
            dependencies: ["PixlRenderer"]
        ),
        .testTarget(
            name: "PixlEditorSupportTests",
            dependencies: [
                "PixlEditorSupport",
                "PixlRenderer",
                .product(name: "PixlMath", package: "PixlMath")
            ]
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
