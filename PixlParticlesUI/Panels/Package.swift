// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Panels",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "Panels",
            targets: ["Panels"]
        ),
    ],
    targets: [
        .target(
            name: "Panels",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        )
    ]
)
