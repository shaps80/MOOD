// swift-tools-version: 6.3
import PackageDescription

let releaseCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-enable-cmo-everything"],
        .when(configuration: .release)
    )
]

let package = Package(
    name: "PixlBackend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PixlBackend",
            targets: ["PixlBackend"]
        ),
        .library(
            name: "PixlMetalBackend",
            targets: ["PixlMetalBackend"]
        ),
        .executable(
            name: "PixlBackendTestRunner",
            targets: ["PixlBackendTestRunner"]
        ),
        .executable(
            name: "PixlBackendBrowserTestRunner",
            targets: ["PixlBackendBrowserTestRunner"]
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
            name: "PixlBackend",
            exclude: ["AGENTS.md", "CONTEXT.md", "PERF.md"],
            swiftSettings: releaseCrossModuleOptimization
        ),
        .target(
            name: "PixlMetalBackend",
            dependencies: ["PixlBackend"]
        ),
        .target(
            name: "PixlBackendTestSupport",
            dependencies: ["PixlBackend"]
        ),
        .executableTarget(
            name: "PixlBackendTestRunner",
            dependencies: ["PixlBackendTestSupport"]
        ),
        .executableTarget(
            name: "PixlBackendBrowserTestRunner",
            dependencies: [
                "PixlBackendTestSupport",
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit",
                    condition: .when(platforms: [.wasi])
                )
            ]
        ),
        .testTarget(
            name: "PixlBackendTests",
            dependencies: ["PixlBackendTestSupport"]
        )
    ],
    swiftLanguageModes: [.v6]
)
