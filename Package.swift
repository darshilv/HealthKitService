// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HealthKitService",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "HealthKitService", targets: ["HealthKitService"]),
    ],
    targets: [
        .target(
            name: "HealthKitService",
            dependencies: []
        ),
        .testTarget(
            name: "HealthKitServiceTests",
            dependencies: ["HealthKitService"]
        ),
    ]
)
