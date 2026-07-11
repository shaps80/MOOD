// swift-tools-version: 6.3
import PackageDescription

let releaseCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-enable-cmo-everything"],
        .when(configuration: .release)
    )
]

let package = Package(
    name: "PixlPlatform",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PixlPlatform",
            targets: ["PixlPlatform"]
        ),
        .library(
            name: "PixlMetalPlatform",
            targets: ["PixlMetalPlatform"]
        ),
        .executable(
            name: "PixlPlatformTestRunner",
            targets: ["PixlPlatformTestRunner"]
        ),
        .executable(
            name: "PixlPlatformBrowserTestRunner",
            targets: ["PixlPlatformBrowserTestRunner"]
        ),
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
            exclude: ["AGENTS.md", "CONTEXT.md", "PERF.md"],
            swiftSettings: releaseCrossModuleOptimization
        ),
        .target(
            name: "PixlMetalPlatform",
            dependencies: ["PixlPlatform"]
        ),
        .target(
            name: "PixlPlatformTestSupport",
            dependencies: ["PixlPlatform"]
        ),
        .executableTarget(
            name: "PixlPlatformTestRunner",
            dependencies: ["PixlPlatformTestSupport"]
        ),
        .executableTarget(
            name: "PixlPlatformBrowserTestRunner",
            dependencies: [
                "PixlPlatformTestSupport",
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit",
                    condition: .when(platforms: [.wasi])
                )
            ]
        ),
        .testTarget(
            name: "PixlPlatformTests",
            dependencies: ["PixlPlatformTestSupport"]
        )
    ],
    swiftLanguageModes: [.v6]
)
