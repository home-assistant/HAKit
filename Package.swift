// swift-tools-version:5.3

import PackageDescription

/// The Package
public let package = Package(
    name: "HAKit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
        .watchOS(.v5),
    ],
    products: [
        .library(
            name: "HAKit",
            targets: ["HAKit"]
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
            name: "HAKit",
            dependencies: [
                .byName(name: "Starscream"),
            ],
            path: "Source"
        ),
        .testTarget(
            name: "Tests",
            dependencies: ["HAKit"],
            path: "Tests"
        ),
    ]
)
