// swift-tools-version: 6.3
import PackageDescription

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
        )
    ],
    dependencies: [
        .package(path: "../PixlPlatform")
    ],
    targets: [
        .target(
            name: "PixlGraphics",
            dependencies: ["PixlPlatform"],
            swiftSettings: defaultNonisolated
        ),
        .target(
            name: "Pixl",
            dependencies: [
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
            ],
            swiftSettings: defaultNonisolated
        )
    ],
    swiftLanguageModes: [.v6]
)
