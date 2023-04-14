// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftDEBot",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/MahdiBM/DiscordBM", revision: "53e8bd10a4489cd5a8c2c7a47d8801e20a3df530"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.15.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.2"),
        .package(url: "https://github.com/AlwaysRightInstitute/cows.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftDEBot",
            dependencies: [
                "DiscordBM",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                "cows",
            ]),
    ]
)
