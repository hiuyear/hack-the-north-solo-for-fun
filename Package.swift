// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BadgeKartBridge",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "badge-kart-bridge", targets: ["BadgeKartBridge"])
    ],
    targets: [
        .executableTarget(name: "BadgeKartBridge"),
        .testTarget(name: "BadgeKartBridgeTests", dependencies: ["BadgeKartBridge"])
    ]
)

