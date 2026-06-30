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
            url: "https://github.com/MasterWordServices/masterword-embedded-ios/releases/download/v0.1.1/MasterWordEmbedded.xcframework.zip",
            checksum: "0519af705cbec634765c46a7dc57dbe91fbd2a111d02ee7acc01a0b7224810f6"
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
