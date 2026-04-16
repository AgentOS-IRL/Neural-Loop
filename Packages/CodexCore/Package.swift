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
        ),
        .executable(
            name: "CodexChatConversation",
            targets: ["CodexChatConversation"]
        )
    ],
    targets: [
        .target(
            name: "CodexCore"
        ),
        .executableTarget(
            name: "CodexChatConversation",
            dependencies: ["CodexCore"]
        ),
        .testTarget(
            name: "CodexCoreTests",
            dependencies: ["CodexCore"]
        )
    ]
)
