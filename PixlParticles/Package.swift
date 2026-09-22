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
            swiftSettings: optimizedSettings()
        ),
        .target(
            name: "PixlRenderer",
            swiftSettings: optimizedSettings()
        ),
        .target(
            name: "PixlMetal",
            dependencies: ["PixlRenderer"],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: optimizedSettings()
        ),
        .target(
            name: "PixlEditorSupport",
            dependencies: [
                "PixlRenderer",
                .product(name: "PixlMath", package: "PixlMath")
            ],
            swiftSettings: optimizedSettings()
        ),
        .target(
            name: "PixlEditorSupportMetal",
            dependencies: ["PixlEditorSupport", "PixlMetal"],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: optimizedSettings()
        ),
        .testTarget(
            name: "PixlParticlesTests",
            dependencies: ["PixlParticles", "PixlRenderer"],
            swiftSettings: optimizedSettings()
        ),
        .testTarget(
            name: "PixlRendererTests",
            dependencies: ["PixlRenderer"],
            swiftSettings: optimizedSettings()
        ),
        .testTarget(
            name: "PixlEditorSupportTests",
            dependencies: [
                "PixlEditorSupport",
                "PixlRenderer",
                .product(name: "PixlMath", package: "PixlMath")
            ],
            swiftSettings: optimizedSettings()
        )
    ],
    swiftLanguageModes: [.v6]
)

private func optimizedSettings() -> [SwiftSetting] {
    [
        .unsafeFlags(["-O"]),
        .unsafeFlags(
            ["-cross-module-optimization"],
            .when(configuration: .release)
        )
    ]
}
