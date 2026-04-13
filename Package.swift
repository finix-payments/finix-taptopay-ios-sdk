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
    targets: [
        .binaryTarget(
            name: "FinixTapToPaySDK",
            path: "Sources/FinixTapToPaySDK.xcframework"
        ),
    ]
)
