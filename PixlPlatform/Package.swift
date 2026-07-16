// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlPlatform",
    products: [
        .library(name: "PixlPlatform", targets: ["PixlPlatform"]),
        .library(name: "PixlWasmPlatform", targets: ["PixlWasmPlatform"]),
        .library(name: "PixlMetalPlatform", targets: ["PixlMetalPlatform"])
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
            swiftSettings: releaseFullCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlWasmPlatform",
            dependencies: [
                "PixlPlatform",
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlMetalPlatform",
            dependencies: ["PixlPlatform"],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .testTarget(
            name: "PixlPlatformTests",
            dependencies: ["PixlPlatform"],
            swiftSettings: defaultNonisolated()
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

private func releaseFullCrossModuleOptimization() -> [SwiftSetting] {
    [
        .unsafeFlags(
            ["-enable-cmo-everything"],
            .when(configuration: .release)
        )
    ]
}

private func defaultNonisolated() -> [SwiftSetting] {
    [.defaultIsolation(nil)]
}
