// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PixlMath",
    products: [
        .library(name: "PixlMath", targets: ["PixlMath"])
    ],
    targets: [
        .target(
            name: "PixlMath",
            dependencies: ["PixlMathC"],
            swiftSettings: releaseWholeModuleOptimization()
                + [.defaultIsolation(nil)]
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

private func releaseWholeModuleOptimization() -> [SwiftSetting] {
    [
        .unsafeFlags(
            ["-whole-module-optimization", "-cross-module-optimization"],
            .when(configuration: .release)
        )
    ]
}
