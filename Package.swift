// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mpet",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SoulCore"),
        .executableTarget(name: "mpet-soul", dependencies: ["SoulCore"]),
        .executableTarget(name: "soulctl", dependencies: ["SoulCore"]),
        .testTarget(name: "SoulCoreTests", dependencies: ["SoulCore"]),
    ]
)
