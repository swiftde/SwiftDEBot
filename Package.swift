// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftDEBot",
    dependencies: [
        .package(url: "https://github.com/Azoy/Sword.git", from: "0.9.2"),
    ],
    targets: [
        .target(
            name: "SwiftDEBot",
            dependencies: ["Sword"]),
    ]
)
