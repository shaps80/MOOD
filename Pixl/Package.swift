// swift-tools-version: 6.3
import PackageDescription

private var dependencies: [Target.Dependency] = [
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

let defaultNonisolated: [SwiftSetting] = [
    .defaultIsolation(nil)
]

let releaseCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-cross-module-optimization"],
        .when(configuration: .release)
    )
]

let package = Package(
    name: "Pixl",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "Pixl",
            targets: ["Pixl"]
        )
    ],
    dependencies: [
        .package(path: "../PixlPlatform"),
        .package(path: "../PixlConcurrency"),
        .package(path: "../PixlMath")
    ],
    targets: [
        .target(
            name: "Pixl",
            dependencies: [
                .product(
                    name: "PixlConcurrency",
                    package: "PixlConcurrency"
                ),
                "Pixl2D",
                "Pixl3D"
                ,
                .product(
                    name: "PixlWasmPlatform",
                    package: "PixlPlatform",
                    condition: .when(platforms: [.wasi])
                )
            ],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        ),
        .target(
            name: "Pixl2D",
            dependencies: dependencies + [
                .product(name: "PixlMath", package: "PixlMath")
            ],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        ),
        .target(
            name: "Pixl3D",
            dependencies: dependencies,
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        ),
        .target(
            name: "PixlGraphics",
            dependencies: ["PixlPlatform"],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated,
            plugins: [
                .plugin(name: "PixlShaderPlugin", package: "PixlPlatform")
            ]
        ),
        .testTarget(
            name: "PixlTests",
            dependencies: ["Pixl"],
            swiftSettings: defaultNonisolated
        ),
    ],
    swiftLanguageModes: [.v6]
)
