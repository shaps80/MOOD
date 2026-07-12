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
    )
]

let defaultNonisolated: [SwiftSetting] = [
    .defaultIsolation(nil)
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
        .package(
            url: "https://github.com/apple/swift-atomics.git",
            from: "1.3.0"
        )
    ],
    targets: [
        .target(
            name: "Pixl",
            dependencies: [
                "PixlExec",
                "Pixl2D",
                "Pixl3D"
            ],
            swiftSettings: defaultNonisolated
        ),
        .target(
            name: "PixlExec",
            dependencies: [
                .product(
                    name: "PixlPlatform",
                    package: "PixlPlatform"
                ),
                .product(name: "Atomics", package: "swift-atomics")
            ],
            swiftSettings: defaultNonisolated
        ),
        .target(
            name: "Pixl2D",
            dependencies: dependencies,
            swiftSettings: defaultNonisolated
        ),
        .target(
            name: "Pixl3D",
            dependencies: dependencies,
            swiftSettings: defaultNonisolated
        ),
        .target(
            name: "PixlGraphics",
            dependencies: ["PixlPlatform"],
            swiftSettings: defaultNonisolated,
            plugins: [
                .plugin(name: "PixlShaderPlugin", package: "PixlPlatform")
            ]
        ),
        .testTarget(
            name: "PixlExecTests",
            dependencies: ["PixlExec"],
            swiftSettings: defaultNonisolated
        ),
    ],
    swiftLanguageModes: [.v6]
)
