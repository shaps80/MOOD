// swift-tools-version: 6.3
import PackageDescription

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
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.55.0"
        )
    ],
    targets: [
        .target(name: "Pixl"),
        .target(
            name: "PlatformWeb",
            dependencies: [
                "Pixl",
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit",
                    condition: .when(platforms: [.wasi])
                )
            ]
        ),
        .target(
            name: "PlatformMac",
            dependencies: [
                "Pixl"
            ],
            resources: [
                .copy("../../Game/assets")
            ]
        ),
        .executableTarget(
            name: "Sandbox",
            dependencies: [
                .target(
                    name: "PlatformWeb",
                    condition: .when(platforms: [.wasi])
                ),
                .target(
                    name: "PlatformMac",
                    condition: .when(platforms: [.macOS])
                )
            ]
        ),
        .executableTarget(
            name: "Invaders",
            dependencies: [
                .target(
                    name: "PlatformMac",
                    condition: .when(platforms: [.macOS])
                ),
                .target(
                    name: "PlatformWeb",
                    condition: .when(platforms: [.wasi])
                )
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
