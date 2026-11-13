// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatteryTime",
    platforms: [.macOS(.v13)],
    products: [.library(name: "BatteryCore", targets: ["BatteryCore"]),
               .library(name: "ChargingBridge", targets: ["ChargingBridge"])],
    targets: [
        .target(name: "BatteryCore"),
        .target(name: "ChargingBridge", cSettings: [.unsafeFlags(["-fobjc-arc"])]),
        .testTarget(name: "ChargingBridgeTests", dependencies: ["ChargingBridge"]),
        .testTarget(name: "BatteryCoreTests", dependencies: ["BatteryCore"]),
        .target(name: "BatteryAppSupport", dependencies: ["BatteryCore", "ChargingBridge"],
                path: "Sources/BatteryTime", exclude: ["main.swift"]),
        .testTarget(name: "BatteryAppTests", dependencies: ["BatteryAppSupport", "BatteryCore"])
    ]
)
