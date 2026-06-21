// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MOOD",
    products: [
        .library(
            name: "GameCore",
            targets: ["GameCore"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.55.0"
        )
    ],
    targets: [
        .target(name: "GameCore"),
        .target(
            name: "PlatformWeb",
            dependencies: [
                "GameCore",
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit"
                )
            ]
        ),
        .executableTarget(
            name: "MOOD",
            dependencies: [
                "PlatformWeb"
            ]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
