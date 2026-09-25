// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MetalRenderBenchmarks",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../..")],
    targets: [.executableTarget(name: "MetalRenderBenchmarks", dependencies: [
        .product(name: "PixlParticles", package: "PixlParticles"),
        .product(name: "PixlMetal", package: "PixlParticles")
    ])]
)
