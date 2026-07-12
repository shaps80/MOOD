// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlMath",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "PixlMath", targets: ["PixlMath"])
    ],
    targets: [
        .target(
            name: "PixlMath",
            dependencies: ["PixlMathC"],
            swiftSettings: [.defaultIsolation(nil)]
        ),
        .target(
            name: "PixlMathC",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "PixlMathTests",
            dependencies: ["PixlMath"],
            swiftSettings: [.defaultIsolation(nil)]
        )
    ],
    swiftLanguageModes: [.v6]
)
