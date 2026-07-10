// swift-tools-version: 6.3
import PackageDescription
import CompilerPluginSupport

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
            name: "PixlStore",
            targets: ["PixlStore"]
        ),
        .library(
            name: "PixlBackend",
            targets: ["PixlBackend"]
        ),
        .library(
            name: "PixlMetalBackend",
            targets: ["PixlMetalBackend"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.55.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.2"
        )
    ],
    targets: [
        .target(name: "Pixl"),
        .target(name: "PixlBackend"),
        .target(
            name: "PixlMetalBackend",
            dependencies: ["PixlBackend"]
        ),
        .target(
            name: "PixlStore",
            dependencies: ["PixlStoreMacros"]
        ),
        .macro(
            name: "PixlStoreMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "PixlStoreTests",
            dependencies: [
                "PixlStore",
                "PixlStoreMacros"
            ]
        ),
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
            ],
            resources: [
                .copy("Resources/assets")
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
            ],
            resources: [
                .copy("Resources/assets")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
