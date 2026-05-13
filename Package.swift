// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MusicBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MusicBar", targets: ["MusicBarApp"])
    ],
    targets: [
        .executableTarget(
            name: "MusicBarApp",
            path: "Sources/MusicBarApp"
        )
    ]
)
