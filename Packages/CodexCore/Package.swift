// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CodexCore",
            targets: ["CodexCore"]
        )
    ],
    targets: [
        .target(
            name: "CodexCore"
        ),
        .testTarget(
            name: "CodexCoreTests",
            dependencies: ["CodexCore"]
        )
    ]
)
