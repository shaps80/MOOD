// swift-tools-version: 6.3
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Pixl",
    platforms: [
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .iOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Pixl",
            targets: ["Pixl"]
        ),
        .library(
            name: "PixlFoundation",
            targets: ["PixlFoundation"]
        ),
        .library(
            name: "PixlText",
            targets: ["PixlText"]
        ),
        .library(
            name: "PixlUI",
            targets: ["PixlUI"]
        ),
        .library(
            name: "Pixl2D",
            targets: ["Pixl2D"]
        ),
        .library(
            name: "Pixl3D",
            targets: ["Pixl3D"]
        ),
        .library(
            name: "PixlGraphics",
            targets: ["PixlGraphics"]
        ),
    ],
    dependencies: [
        .package(path: "../PixlPlatform"),
        .package(path: "../PixlMath"),
        .package(
            url: "https://github.com/apple/swift-atomics.git",
            from: "1.3.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "603.0.2"
        )
    ],
    targets: [
        .target(
            name: "Pixl",
            dependencies: [
                "PixlMacros",
                "PixlFoundation",
                "PixlGraphics",
                "Pixl2D",
                "Pixl3D",
                "PixlUI",
                .product(
                    name: "PixlPlatform",
                    package: "PixlPlatform"
                ),
                .product(
                    name: "PixlMetalPlatform",
                    package: "PixlPlatform",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "PixlWasmPlatform",
                    package: "PixlPlatform",
                    condition: .when(platforms: [.wasi])
                )
            ],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlFoundation",
            dependencies: [
                .product(
                    name: "Atomics",
                    package: "swift-atomics"
                ),
                .product(
                    name: "PixlPlatform",
                    package: "PixlPlatform"
                )
            ],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .macro(
            name: "PixlMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .target(
            name: "Pixl2D",
            dependencies: [
                "PixlGraphics",
                .product(name: "PixlMath", package: "PixlMath")
            ],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "Pixl3D",
            dependencies: ["PixlGraphics"],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlGraphics",
            swiftSettings: releaseCrossModuleOptimization()
                + defaultNonisolated()
                + [.enableExperimentalFeature("Lifetimes")]
        ),
        .target(
            name: "PixlText",
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlUI",
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .testTarget(
            name: "Pixl2DTests",
            dependencies: [
                "Pixl2D",
                "PixlGraphics"
            ],
            swiftSettings: defaultNonisolated()
        ),
        .testTarget(
            name: "PixlTests",
            dependencies: [
                "Pixl",
                "Pixl2D",
                "PixlFoundation",
                "PixlGraphics",
                .product(
                    name: "PixlMetalPlatform",
                    package: "PixlPlatform"
                )
            ],
            swiftSettings: defaultNonisolated()
        ),
    ],
    swiftLanguageModes: [.v6]
)

private func defaultNonisolated() -> [SwiftSetting] {
    [.defaultIsolation(nil)]
}

private func releaseCrossModuleOptimization() -> [SwiftSetting] {
    [
        .unsafeFlags(
            ["-cross-module-optimization"],
            .when(configuration: .release)
        )
    ]
}
