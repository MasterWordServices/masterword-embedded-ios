// swift-tools-version: 5.9
import PackageDescription

// MasterWordEmbedded is distributed as a pre-built XCFramework.
// TwilioVideo is declared here so SPM automatically includes it in your app bundle —
// you do not need to add it as a separate dependency.
// SignalRClient is statically linked inside the XCFramework and requires no action.

let package = Package(
    name: "MasterWordEmbedded",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MasterWordEmbedded", targets: ["MasterWordEmbedded"]),
    ],
    dependencies: [
        .package(url: "https://github.com/twilio/twilio-video-ios", from: "5.11.3"),
    ],
    targets: [
        .binaryTarget(
            name: "MasterWordEmbeddedCore",
            url: "https://github.com/MasterWordServices/masterword-embedded-ios/releases/download/v0.1.0/MasterWordEmbedded.xcframework.zip",
            checksum: "c575afe6b0919d6714e860ab9e3533567ca7dc5bf16cd2c37b48f75e48bb58b6"
        ),
        .target(
            name: "MasterWordEmbedded",
            dependencies: [
                "MasterWordEmbeddedCore",
                .product(name: "TwilioVideo", package: "twilio-video-ios"),
            ],
            path: "Sources/MasterWordEmbedded"
        ),
    ]
)
