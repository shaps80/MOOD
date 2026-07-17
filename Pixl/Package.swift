// swift-tools-version: 6.3
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Pixl",
    platforms: [
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16),
        .iOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Pixl",
            targets: ["Pixl"]
        ),
        .library(
            name: "PixlText",
            targets: ["PixlText"]
        ),
        .library(
            name: "PixlUI",
            targets: ["PixlUI"]
        )
    ],
    dependencies: [
        .package(path: "../PixlPlatform"),
        .package(path: "../PixlMath"),
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
                "PixlGraphics",
                "Pixl2D",
                "Pixl3D"
                ,
                .product(
                    name: "PixlWasmPlatform",
                    package: "PixlPlatform",
                    condition: .when(platforms: [.wasi])
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
            dependencies: dependencies() + [
                .product(name: "PixlMath", package: "PixlMath")
            ],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "Pixl3D",
            dependencies: dependencies(),
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlGraphics",
            dependencies: ["PixlPlatform"],
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
            name: "PixlTests",
            dependencies: [
                "Pixl",
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

private func dependencies() -> [Target.Dependency] {
    [
        "PixlGraphics",
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
    ]
}

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
