// swift-tools-version: 6.3
import PackageDescription

let releaseCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-enable-cmo-everything"],
        .when(configuration: .release)
    )
]

let package = Package(
    name: "PixlConcurrency",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "PixlConcurrency",
            targets: ["PixlConcurrency"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-atomics.git",
            from: "1.3.0"
        )
    ],
    targets: [
        .target(
            name: "PixlConcurrency",
            dependencies: [
                "PixlConcurrencyC",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            swiftSettings: releaseCrossModuleOptimization + [
                .defaultIsolation(nil)
            ]
        ),
        .target(
            name: "PixlConcurrencyC",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "PixlConcurrencyTests",
            dependencies: ["PixlConcurrency"],
            swiftSettings: [.defaultIsolation(nil)]
        )
    ],
    swiftLanguageModes: [.v6]
)
