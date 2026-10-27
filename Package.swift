// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpatialWhiteboard",
    platforms: [.macOS(.v13), .visionOS("2.0")],
    products: [.library(name: "BoardCore", targets: ["BoardCore"])],
    targets: [
        .target(name: "BoardCore"),
        .testTarget(name: "BoardCoreTests", dependencies: ["BoardCore"])
    ]
)
