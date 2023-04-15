// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftDEBot",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/MahdiBM/DiscordBM", exact: "1.0.0-beta.49"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.15.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.2"),
        .package(url: "https://github.com/DimaRU/PackageBuildInfo.git", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/AlwaysRightInstitute/cows.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftDEBot",
            dependencies: [
                "DiscordBM",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                "cows",
            ],
            plugins: [
                .plugin(name: "PackageBuildInfoPlugin", package: "PackageBuildInfo")
            ]
        ),
    ]
)
