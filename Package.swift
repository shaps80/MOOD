// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MOOD",
    platforms: [
        .macOS(.v13)
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
                    package: "JavaScriptKit",
                    condition: .when(platforms: [.wasi])
                )
            ]
        ),
        .target(
            name: "PlatformMac",
            dependencies: [
                "GameCore"
            ],
            resources: [
                .copy("../../Game/assets")
            ]
        ),
        .executableTarget(
            name: "MOOD",
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
        )
    ],
    swiftLanguageModes: [.v6]
)
