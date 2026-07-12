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
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Pixl",
            targets: ["Pixl"]
        ),
        .library(
            name: "Pixl2D",
            targets: ["Pixl2D"]
        ),
        .library(
            name: "Pixl3D",
            targets: ["Pixl3D"]
        )
    ],
    dependencies: [
        .package(path: "../PixlPlatform")
    ],
    targets: [
        .target(
            name: "Pixl",
            dependencies: [
                "Pixl2D",
                "Pixl3D"
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
    ],
    swiftLanguageModes: [.v6]
)
