// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "PixlMemory",
    products: [
        .library(name: "PixlMemory", targets: ["PixlMemory"]),
        .executable(name: "Sandbox", targets: ["Sandbox"])
    ],
    targets: [
        .target(
            name: "PixlMemory",
            swiftSettings: [.defaultIsolation(nil)]
        ),
        .executableTarget(
            name: "Sandbox",
            dependencies: ["PixlMemory"],
            swiftSettings: [.defaultIsolation(nil)]
        )
    ],
    swiftLanguageModes: [.v6]
)
