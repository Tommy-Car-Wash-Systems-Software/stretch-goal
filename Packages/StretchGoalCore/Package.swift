// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StretchGoalCore",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "StretchGoalCore", targets: ["StretchGoalCore"]),
    ],
    targets: [
        .target(name: "StretchGoalCore"),
        .testTarget(name: "StretchGoalCoreTests", dependencies: ["StretchGoalCore"]),
    ]
)
