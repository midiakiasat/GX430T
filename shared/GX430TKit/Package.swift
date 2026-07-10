// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GX430TKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GX430TKit",
            targets: ["GX430TKit"]
        )
    ],
    targets: [
        .target(
            name: "GX430TKit"
        )
    ]
)
