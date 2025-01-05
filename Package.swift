// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PNG3D",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PNG3D",
            targets: ["PNG3D"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/AsyncGraphics", from: "2.1.2"),
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
