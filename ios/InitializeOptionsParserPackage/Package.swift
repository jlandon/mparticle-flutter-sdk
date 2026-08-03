// swift-tools-version: 6.0
//
// Thin test package for InitializeOptionsParser unit tests (depends on main plugin package).
import PackageDescription

let package = Package(
    name: "InitializeOptionsParserPackage",
    platforms: [
        .iOS("15.6"),
        .macOS(.v12),
    ],
    dependencies: [
        .package(name: "mparticle_flutter_sdk", path: "../mparticle_flutter_sdk"),
    ],
    targets: [
        .testTarget(
            name: "InitializeOptionsParserTests",
            dependencies: [
                .product(name: "InitializeOptionsParser", package: "mparticle_flutter_sdk"),
            ],
            path: "Tests/InitializeOptionsParserTests"
        ),
    ]
)
