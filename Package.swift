// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "MusicBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MusicBar", targets: ["MusicBarApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "MusicBarApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MusicBarApp"
        )
    ]
)
