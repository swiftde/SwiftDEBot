// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "SwiftDEBot",
    dependencies: [
        .package(url: "https://github.com/Azoy/Sword.git", from: "0.9.2"),
        .package(url: "https://github.com/AlwaysRightInstitute/cows.git", from: "1.0.0"),

        // Remove me when upgrading to a more current version of Swift.
        .package(url: "https://github.com/antitypical/Result", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftDEBot",
            dependencies: [
                "Sword",
                "cows",
                "Result"
            ]),
    ]
)
