// swift-tools-version: 6.0
//
// Unit tests for InitializeOptionsParser (sources in InitializeOptionsParserCore).
import PackageDescription

let package = Package(
    name: "InitializeOptionsParserPackage",
    platforms: [
        .iOS("15.6"),
        .macOS(.v12),
    ],
    dependencies: [
        .package(path: "../InitializeOptionsParserCore"),
    ],
    targets: [
        .testTarget(
            name: "InitializeOptionsParserTests",
            dependencies: [
                .product(name: "InitializeOptionsParser", package: "InitializeOptionsParserCore"),
            ],
            path: "Tests/InitializeOptionsParserTests"
        ),
    ]
)
