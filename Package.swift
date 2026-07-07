// swift-tools-version:5.3

import PackageDescription

/// The Package
public let package = Package(
    name: "HAKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "HAKit",
            targets: ["HAKit"]
        ),
        .library(
            name: "HAKit+PromiseKit",
            targets: ["HAKit+PromiseKit"]
        ),
        .library(
            name: "HAKit+Mocks",
            targets: ["HAKit+Mocks"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/bgoncal/Starscream",
            from: "4.0.9"
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
