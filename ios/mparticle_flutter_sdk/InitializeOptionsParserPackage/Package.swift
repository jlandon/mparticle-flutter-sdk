// swift-tools-version: 6.0
//
// UIKit-free parser shared by the Flutter plugin SPM target and unit tests.
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
