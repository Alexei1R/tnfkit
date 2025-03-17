// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tnfkit",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "tnfkit",
            targets: ["tnfkit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "tnfkit",
            dependencies: [],
            path: "Sources/tnfkit",
            resources: [
                .process("Assets")
            ]
        )
    ]
)
