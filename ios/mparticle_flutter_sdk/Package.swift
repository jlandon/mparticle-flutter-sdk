// swift-tools-version: 6.0
//
// Version lock table (pod ↔ SPM):
// | Dependency            | CocoaPods        | SPM floor |
// | --------------------- | ---------------- | --------- |
// | mParticle-Apple-SDK   | ~> 9.2           | 9.2.0     |
// | mParticle-Rokt        | (transitive)     | 9.0.0     |
// | RoktPaymentExtension  | (transitive)     | 2.0.0     |
// | RoktContracts         | (via mParticle-Rokt) | 2.0.0 |
//
import PackageDescription

let package = Package(
    name: "mparticle_flutter_sdk",
    platforms: [
        .iOS("15.6"),
        .macOS(.v12),
    ],
    products: [
        .library(name: "mparticle-flutter-sdk", targets: ["mparticle_flutter_sdk"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(path: "InitializeOptionsParserPackage"),
        .package(url: "https://github.com/mParticle/mparticle-apple-sdk", from: "9.2.0"),
        .package(url: "https://github.com/mparticle-integrations/mp-apple-integration-rokt", from: "9.0.0"),
        .package(url: "https://github.com/ROKT/rokt-payment-extension-ios", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "mparticle_flutter_sdk",
            dependencies: [
                .product(name: "InitializeOptionsParser", package: "InitializeOptionsParserPackage"),
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "mParticle-Apple-SDK", package: "mparticle-apple-sdk"),
                .product(name: "mParticle-Rokt", package: "mp-apple-integration-rokt"),
                .product(name: "RoktPaymentExtension", package: "rokt-payment-extension-ios"),
            ],
            path: "Sources/mparticle_flutter_sdk",
            exclude: [
                "MparticleFlutterSdkPlugin.m",
                "include",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
