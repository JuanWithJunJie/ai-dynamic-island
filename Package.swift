// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacIrland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacIrlandKit",
            targets: ["MacIrlandKit"]
        ),
        .executable(
            name: "MacIrland",
            targets: ["MacIrlandApp"]
        )
    ],
    targets: [
        .target(
            name: "MacIrlandKit",
            path: "MacIrlandKit"
        ),
        .executableTarget(
            name: "MacIrlandApp",
            dependencies: ["MacIrlandKit"],
            path: "MacIrlandApp",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "MacIrlandTests",
            dependencies: [
                "MacIrlandKit",
                "MacIrlandApp"
            ],
            path: "MacIrlandTests"
        )
    ]
)
