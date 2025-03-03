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
            targets: ["tnfkit", "Core", "Engine"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "tnfkit",
            dependencies: ["Core", "Engine"],
            path: "Sources/tnfkit",
            resources: [
                .process("Assets")
            ]
        ),

        .target(
            name: "Core",
            dependencies: [],
            path: "Sources/Core"
        ),

        .target(
            name: "Engine",
            dependencies: ["Core"],
            path: "Sources/Engine"
        ),
    ]
)
