// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlPlatform",
    platforms: [
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16),
        .iOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "PixlPlatform", targets: ["PixlPlatform"]),
        .library(name: "PixlSynchronization", targets: ["PixlSynchronization"]),
        .library(name: "PixlWasmPlatform", targets: ["PixlWasmPlatform"]),
        .library(name: "PixlMetalPlatform", targets: ["PixlMetalPlatform"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.55.0"
        ),
        .package(
            url: "https://github.com/apple/swift-atomics.git",
            from: "1.3.0"
        ),
    ],
    targets: [
        .target(
            name: "PixlPlatform",
            dependencies: [
                "PixlSynchronization"
            ],
            swiftSettings: releaseFullCrossModuleOptimization() + defaultNonisolated()
        ),
        .target(
            name: "PixlSynchronization",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ],
            swiftSettings: defaultNonisolated()
        ),
        .target(
            name: "PixlWasmPlatform",
            dependencies: [
                "PixlPlatform",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            exclude: ["Shaders"],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
            
        ),
        .target(
            name: "PixlMetalPlatform",
            dependencies: [
                "PixlPlatform",
                "PixlSynchronization",
            ],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: releaseCrossModuleOptimization() + defaultNonisolated()
        ),
        .testTarget(
            name: "PixlPlatformTests",
            dependencies: [
                "PixlPlatform",
                .target(
                    name: "PixlMetalPlatform",
                    condition: .when(platforms: [.macOS])
                ),
            ],
            swiftSettings: defaultNonisolated()
        ),
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
