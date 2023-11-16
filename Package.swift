// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PNG3D",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v12),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PNG3D",
            targets: ["PNG3D"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/AsyncGraphics", from: "1.8.1"),
        .package(url: "https://github.com/marmelroy/Zip", from: "2.1.2"),
    ],
    targets: [
        .target(
            name: "PNG3D",
            dependencies: ["AsyncGraphics", "Zip"]),
        .testTarget(
            name: "PNG3DTests",
            dependencies: ["PNG3D"]),
    ]
)
