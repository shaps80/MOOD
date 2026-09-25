// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "PixlProfiler",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "PixlProfiler", targets: ["PixlProfiler"]),
        .library(name: "PixlProfilerUI", targets: ["PixlProfilerUI"])
    ],
    targets: [
        .target(name: "PixlProfiler"),
        .target(name: "PixlProfilerUI", dependencies: ["PixlProfiler"]),
        .testTarget(name: "PixlProfilerTests", dependencies: ["PixlProfiler"]),
        .testTarget(name: "PixlProfilerUITests", dependencies: ["PixlProfiler", "PixlProfilerUI"])
    ], swiftLanguageModes: [.v6]
)
