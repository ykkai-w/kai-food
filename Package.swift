// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KaiiFood",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KaiiFoodCore", targets: ["KaiiFoodCore"]),
        .executable(name: "KaiiFoodPreview", targets: ["KaiiFoodPreview"]),
        .executable(name: "KaiiFoodCoreCheck", targets: ["KaiiFoodCoreCheck"])
    ],
    targets: [
        .target(name: "KaiiFoodCore"),
        .executableTarget(name: "KaiiFoodPreview", dependencies: ["KaiiFoodCore"], path: "App", exclude: ["Assets.xcassets"], resources: [.process("Resources")]),
        .executableTarget(name: "KaiiFoodCoreCheck", dependencies: ["KaiiFoodCore"], path: "Tests/KaiiFoodCoreCheck"),
        .testTarget(name: "KaiiFoodCoreTests", dependencies: ["KaiiFoodCore"])
    ]
)
