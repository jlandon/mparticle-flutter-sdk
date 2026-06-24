// swift-tools-version: 5.9
//
// Standalone package for InitializeOptionsParser unit tests (no FlutterFramework).
import PackageDescription

let package = Package(
    name: "InitializeOptionsParserPackage",
    platforms: [
        .iOS("15.6"),
        .macOS(.v12),
    ],
    products: [
        .library(name: "InitializeOptionsParser", targets: ["InitializeOptionsParser"]),
    ],
    targets: [
        .target(
            name: "InitializeOptionsParser",
            path: "Sources/InitializeOptionsParser"
        ),
        .testTarget(
            name: "InitializeOptionsParserTests",
            dependencies: ["InitializeOptionsParser"],
            path: "Tests/InitializeOptionsParserTests"
        ),
    ]
)
