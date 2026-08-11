// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OvertureRockets",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "OvertureRockets",
            targets: ["OvertureRockets"]
        ),
    ],
    targets: [
        .target(
            name: "OvertureRockets",
            resources: [
                .process("OvertureRockets.rkassets"),
            ]
        ),
    ]
)
