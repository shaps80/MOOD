// swift-tools-version: 6.3
import PackageDescription
import Foundation

let releaseCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-cross-module-optimization"],
        .when(configuration: .release)
    )
]

let releaseFullCrossModuleOptimization: [SwiftSetting] = [
    .unsafeFlags(
        ["-enable-cmo-everything"],
        .when(configuration: .release)
    )
]

let defaultNonisolated: [SwiftSetting] = [
    .defaultIsolation(nil)
]

let buildsPortableTests = ProcessInfo.processInfo.environment["PIXL_PLATFORM_TEST"] == "1"

var products: [Product] = [
    .library(name: "PixlPlatform", targets: ["PixlPlatform"])
]

if !buildsPortableTests {
    products.append(.library(name: "PixlWasmPlatform", targets: ["PixlWasmPlatform"]))
    products.append(.plugin(name: "PixlShaderPlugin", targets: ["PixlShaderPlugin"]))
}

if !buildsPortableTests {
    products.append(.library(name: "PixlMetalPlatform", targets: ["PixlMetalPlatform"]))
}

var targets: [Target] = [
    .target(
        name: "PixlPlatform",
        swiftSettings: releaseFullCrossModuleOptimization + defaultNonisolated
    ),
    .testTarget(
        name: "PixlPlatformTests",
        dependencies: ["PixlPlatform"],
        swiftSettings: defaultNonisolated
    )
]

if !buildsPortableTests {
    targets.append(
        .target(
            name: "PixlWasmPlatform",
            dependencies: [
                "PixlPlatform",
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        )
    )
    targets.append(.executableTarget(name: "PixlShaderGenerator"))
    targets.append(
        .plugin(
            name: "PixlShaderPlugin",
            capability: .buildTool(),
            dependencies: ["PixlShaderGenerator"]
        )
    )
}

if !buildsPortableTests {
    targets.append(
        .target(
            name: "PixlMetalPlatform",
            dependencies: ["PixlPlatform"],
            swiftSettings: releaseCrossModuleOptimization + defaultNonisolated
        )
    )
}

let package = Package(
    name: "PixlPlatform",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v2)
    ],
    products: products,
    dependencies: buildsPortableTests ? [] : [
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.55.0"
        )
    ],
    targets: targets,
    swiftLanguageModes: [.v6]
)
