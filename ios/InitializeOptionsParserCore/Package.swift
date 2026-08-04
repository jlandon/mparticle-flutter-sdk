// swift-tools-version: 6.0
//
// UIKit-free parser shared by the Flutter plugin SPM target and unit tests.
import PackageDescription

let package = Package(
    name: "InitializeOptionsParserCore",
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
    ]
)
