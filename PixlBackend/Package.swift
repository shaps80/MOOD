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
    ],
    targets: [
        .target(
            name: "PixlBackend",
            exclude: ["AGENTS.md", "CONTEXT.md"],
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
        .testTarget(
            name: "PixlBackendTests",
            dependencies: ["PixlBackendTestSupport"]
        )
    ],
    swiftLanguageModes: [.v6]
)
