// swift-tools-version: 5.9
// The public package manifest. ci_scripts/ci_post_xcodebuild.sh copies it to the root of
// finix-taptopay-ios-sdk next to Sources/FinixTapToPaySDK.xcframework and
// Sources/FinixTapToPaySDKDatadog.

import PackageDescription

let package = Package(
    name: "FinixTapToPaySDK",
    platforms: [
        .iOS("18.1"),
    ],
    products: [
        .library(
            name: "FinixTapToPaySDK",
            targets: ["FinixTapToPaySDKDatadog"]
        ),
    ],
    dependencies: [
        // A range, so SPM can settle on the version an app that already uses Datadog resolves.
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", from: "3.6.1"),
    ],
    targets: [
        .binaryTarget(
            name: "FinixTapToPaySDK",
            path: "Sources/FinixTapToPaySDK.xcframework"
        ),
        // Compiled in the app: connects the binary to the app's single copy of Datadog.
        .target(
            name: "FinixTapToPaySDKDatadog",
            dependencies: [
                "FinixTapToPaySDK",
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogLogs", package: "dd-sdk-ios"),
                .product(name: "DatadogCrashReporting", package: "dd-sdk-ios"),
            ]
        ),
    ]
)
