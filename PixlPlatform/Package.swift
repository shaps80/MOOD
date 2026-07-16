// swift-tools-version: 6.3
import PackageDescription

let releaseCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-cross-module-optimization"],
        .when(configuration: .release)
    )
]

let releaseFullCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-enable-cmo-everything"],
        .when(configuration: .release)
    )
]

let defaultNonisolated: [SwiftSetting] = [
    .defaultIsolation(nil)
]

let package = Package(
    name: "PixlPlatform",
    products: [
        .library(name: "PixlPlatform", targets: ["PixlPlatform"]),
        .library(name: "PixlWasmPlatform", targets: ["PixlWasmPlatform"]),
        .library(name: "PixlMetalPlatform", targets: ["PixlMetalPlatform"]),
        .plugin(name: "PixlShaderPlugin", targets: ["PixlShaderPlugin"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.55.0"
        )
    ],
    targets: [
        .target(
            name: "PixlPlatform",
            swiftSettings: releaseFullCrossModuleOptimization + defaultNonisolated
        ),
        .target(
            name: "PixlWasmPlatform",
            dependencies: [
                "PixlPlatform",
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        ),
        .executableTarget(
            name: "PixlShaderGenerator"
        ),
        .plugin(
            name: "PixlShaderPlugin",
            capability: .buildTool(),
            dependencies: ["PixlShaderGenerator"]
        ),
        .target(
            name: "PixlMetalPlatform",
            dependencies: ["PixlPlatform"],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        ),
        .testTarget(
            name: "PixlPlatformTests",
            dependencies: ["PixlPlatform"],
            swiftSettings: defaultNonisolated
        )
    ],
    swiftLanguageModes: [.v6]
)
