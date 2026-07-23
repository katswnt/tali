// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TaliCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HabitCore", targets: ["HabitCore"])
    ],
    targets: [
        .target(
            name: "HabitCore",
            path: "Shared"
        ),
        .testTarget(
            name: "HabitCoreTests",
            dependencies: ["HabitCore"],
            path: "Tests"
        )
    ]
)
