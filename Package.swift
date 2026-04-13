// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FinixTapToPaySDK",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "FinixTapToPaySDK",
            targets: ["FinixTapToPaySDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/DataDog/dd-sdk-ios", exact: "3.6.1"),
    ],
    targets: [
        .target(
            name: "FinixTapToPaySDK",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogLogs", package: "dd-sdk-ios"),
                .product(name: "DatadogCrashReporting", package: "dd-sdk-ios"),
            ],
            path: "FinixTapToPaySDK",
            exclude: [
                "Info.plist",
            ],
            swiftSettings: [
                .define("INTERNAL_BUILD", .when(configuration: .debug)),
            ]
        ),
    ]
)
