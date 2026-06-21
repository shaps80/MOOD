// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MOOD",
    targets: [
        .target(name: "GameCore"),
        .target(
            name: "PlatformWeb",
            dependencies: ["GameCore"]
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
