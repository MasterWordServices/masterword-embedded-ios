// swift-tools-version: 5.9
import PackageDescription

// MasterWordEmbedded is distributed as a pre-built XCFramework.
// TwilioVideo and TwilioVoice are declared here so SPM automatically includes them in your
// app bundle — you do not need to add them as separate dependencies.
// SignalRClient and Lottie are statically linked inside the XCFramework and require no action.

let package = Package(
    name: "MasterWordEmbedded",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MasterWordEmbedded", targets: ["MasterWordEmbedded", "MasterWordEmbeddedDeps"]),
    ],
    dependencies: [
        .package(url: "https://github.com/twilio/twilio-video-ios", from: "5.11.3"),
        .package(url: "https://github.com/twilio/twilio-voice-ios", from: "6.13.6"),
    ],
    targets: [
        .binaryTarget(
            name: "MasterWordEmbedded",
            url: "https://github.com/MasterWordServices/masterword-embedded-ios/releases/download/v2.1.0/MasterWordEmbedded.xcframework.zip",
            checksum: "99251ac1537c05031e7993d6cb1d949fcbb80ac4dc428de5b4c42dd5056d32e8"
        ),
        // Thin shim: importing these dynamic frameworks forces SPM to embed them into the
        // consuming app so dyld can resolve them at launch. The binary target links against
        // them but does not propagate them on its own.
        .target(
            name: "MasterWordEmbeddedDeps",
            dependencies: [
                .product(name: "TwilioVideo", package: "twilio-video-ios"),
                .product(name: "TwilioVoice", package: "twilio-voice-ios"),
            ],
            path: "Sources/MasterWordEmbeddedDeps"
        ),
    ]
)
