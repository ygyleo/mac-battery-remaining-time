// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatteryTime",
    platforms: [.macOS(.v13)],
    products: [.library(name: "BatteryCore", targets: ["BatteryCore"])],
    targets: [
        .target(name: "BatteryCore"),
        .testTarget(name: "BatteryCoreTests", dependencies: ["BatteryCore"]),
        .target(name: "BatteryAppSupport", dependencies: ["BatteryCore"],
                path: "Sources/BatteryTime", exclude: ["main.swift"]),
        .testTarget(name: "BatteryAppTests", dependencies: ["BatteryAppSupport", "BatteryCore"])
    ]
)
