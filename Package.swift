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
            url: "https://github.com/bgoncal/Starscream",
            from: "4.0.8"
        ),
        .package(
            url: "https://github.com/mxcl/PromiseKit",
            from: "8.1.1"
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
        .target(
            name: "HAKit+PromiseKit",
            dependencies: [
                .byName(name: "HAKit"),
                .byName(name: "PromiseKit"),
            ],
            path: "Extensions/PromiseKit"
        ),
        .target(
            name: "HAKit+Mocks",
            dependencies: [
                .byName(name: "HAKit"),
            ],
            path: "Extensions/Mocks"
        ),
        .testTarget(
            name: "Tests",
            dependencies: [
                .byName(name: "HAKit"),
                .byName(name: "HAKit+PromiseKit"),
                .byName(name: "HAKit+Mocks"),
            ],
            path: "Tests"
        ),
    ]
)
