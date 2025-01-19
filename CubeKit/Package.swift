// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CubeKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "CubeKit",
            targets: ["CubeKit"]
        ),
    ],
    targets: [
        .target(
            name: "CubeKit",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "CubeKitTests",
            dependencies: ["CubeKit"]
        ),
    ]
)
