// swift-tools-version:5.3

import PackageDescription

/// The Package
public let package = Package(
    name: "HAWebSocket",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
        .watchOS(.v5),
    ],
    products: [
        .library(
            name: "HAWebSocket",
            targets: ["HAWebSocket"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/daltoniam/Starscream",
            from: "4.0.4"
        ),
    ],
    targets: [
        .target(
            name: "HAWebSocket",
            dependencies: [
                .byName(name: "Starscream"),
            ],
            path: "Source"
        ),
        .testTarget(
            name: "Tests",
            dependencies: ["HAWebSocket"],
            path: "Tests"
        ),
    ]
)
