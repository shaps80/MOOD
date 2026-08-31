// swift-tools-version: 6.4
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PixlMemory",
    products: [
        .library(name: "PixlMemory", targets: ["PixlMemory"]),
        .executable(name: "Sandbox", targets: ["Sandbox"]),
        .executable(name: "Benchmarks", targets: ["Benchmarks"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-atomics.git",
            from: "1.3.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.2"
        )
    ],
    targets: [
        .target(
            name: "PixlMemory",
            dependencies: [
                "PixlMemoryMacros",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            swiftSettings: defaultNonisolated() + releaseCrossModuleOptimization()
        ),
        .macro(
            name: "PixlMemoryMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "Sandbox",
            dependencies: ["PixlMemory"],
            swiftSettings: defaultNonisolated()
        ),
        .executableTarget(
            name: "Benchmarks",
            dependencies: ["PixlMemory"],
            path: "Benchmarks",
            swiftSettings: defaultNonisolated()
        ),
        .testTarget(
            name: "PixlMemoryTests",
            dependencies: [
                "PixlMemory",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            swiftSettings: defaultNonisolated()
        )
    ],
    swiftLanguageModes: [.v6]
)

private func defaultNonisolated() -> [SwiftSetting] {
    [.defaultIsolation(nil)]
}

private func releaseCrossModuleOptimization() -> [SwiftSetting] {
    [
        .unsafeFlags(
            ["-cross-module-optimization"],
            .when(configuration: .release)
        )
    ]
}
