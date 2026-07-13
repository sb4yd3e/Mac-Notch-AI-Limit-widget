// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AILimitNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AILimitNotch", targets: ["AILimitNotch"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "AILimitNotch",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/AILimitNotch",
            resources: [
                .process("claudecode.png"),
                .process("codex.png"),
                .process("antigravity.png"),
                .process("cursor.png")
            ]
        )
    ]
)
