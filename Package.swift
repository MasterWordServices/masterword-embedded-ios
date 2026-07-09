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
        .library(name: "MasterWordEmbedded", targets: ["MasterWordEmbedded", "MasterWordEmbeddedDeps"]),
    ],
    dependencies: [
        .package(url: "https://github.com/twilio/twilio-video-ios", from: "5.11.3"),
    ],
    targets: [
        .binaryTarget(
            name: "MasterWordEmbedded",
            url: "https://github.com/MasterWordServices/masterword-embedded-ios/releases/download/v2.0.0/MasterWordEmbedded.xcframework.zip",
            checksum: "2dee6935e33485a4e99edc0d5d4581f263e1bd171df538bf4ed2a2edd2f7f0d5"
        ),
        .target(
            name: "MasterWordEmbeddedDeps",
            dependencies: [
                .product(name: "TwilioVideo", package: "twilio-video-ios"),
            ],
            path: "Sources/MasterWordEmbeddedDeps"
        ),
    ]
)
