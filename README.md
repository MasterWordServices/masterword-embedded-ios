# MasterWord Embedded iOS SDK

Embed live interpreter access into your iOS app. The SDK handles authentication, provides a ready-made login UI, and connects users to a MasterWord interpreter on demand — including a context handoff so the interpreter is immediately up to speed.

---

## Requirements

- iOS 16.0+
- Xcode 16.0+
- Swift 6.0+

---

## Installation

### Swift Package Manager

In Xcode, go to **File → Add Package Dependencies** and enter:

```
https://github.com/MasterWordServices/masterword-embedded-ios
```

Or add it manually to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MasterWordServices/masterword-embedded-ios", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["MasterWordEmbedded"]),
]
```

---

## Privacy — Face ID Usage

The SDK uses Face ID to silently restore authenticated sessions on relaunch. Your app's `Info.plist` must include `NSFaceIDUsageDescription` or the app will crash at launch.

If your target uses a generated Info.plist (Xcode 15+), add the key via **Build Settings**:

| Setting | Value |
|---|---|
| `INFOPLIST_KEY_NSFaceIDUsageDescription` | `"MasterWord uses Face ID to sign you in quickly and securely."` |

If your target uses a static `Info.plist`, add the key directly:

```xml
<key>NSFaceIDUsageDescription</key>
<string>MasterWord uses Face ID to sign you in quickly and securely.</string>
```

---

## Privacy — Camera & Microphone

The SDK requests camera and microphone access before placing a call. Add usage descriptions to your `Info.plist` or the system will deny access silently:

| Key | Example value |
|---|---|
| `NSCameraUsageDescription` | `"MasterWord needs camera access for video interpreter calls."` |
| `NSMicrophoneUsageDescription` | `"MasterWord needs microphone access for interpreter calls."` |

---

## Background Modes

Calls continue when the user presses the home button or switches apps. The SDK automatically starts Picture in Picture (PiP) when the app is backgrounded, keeping the interpreter's video visible as a floating window. When the user taps the PiP window, the call sheet restores exactly where it left off.

Your app must declare the **Audio, AirPlay, and Picture in Picture** background mode or iOS will suspend the audio session when the app backgrounds, silently dropping the call.

In Xcode, go to your target's **Signing & Capabilities** tab, click **+ Capability**, and add **Background Modes**. Then check:

- [x] Audio, AirPlay, and Picture in Picture

Or add it directly to your `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

---

## Setup

Create a single `MasterWordSDK` instance at the root of your app, inject it into the environment, and apply `.masterWordSheet(sdk:)` to your root view. The modifier handles all SDK UI presentation — the login card and call screen — automatically.

```swift
import SwiftUI
import MasterWordEmbedded

@main
struct YourApp: App {
    @StateObject private var masterWord = MasterWordSDK()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(masterWord)
                .masterWordSheet(sdk: masterWord)
        }
    }
}
```

Call `checkAuthStatus()` on launch to silently restore a previous session via biometrics.

```swift
struct ContentView: View {
    @EnvironmentObject var masterWord: MasterWordSDK

    var body: some View {
        YourRootView()
            .task { await masterWord.checkAuthStatus() }
    }
}
```

---

## Authentication

`authState` reflects the current session state. Use it to show account info or adapt your UI.

```swift
@EnvironmentObject var masterWord: MasterWordSDK

var body: some View {
    if case .authenticated(let user) = masterWord.authState {
        Text("Signed in as \(user.firstName) \(user.lastName)")
    }
}
```

The login UI is presented automatically by `.masterWordSheet(sdk:)` when needed — you do not embed `LoginCardView` directly.

To sign out:

```swift
masterWord.logout()
```

---

## Requesting an Interpreter

`requestInterpreter(contextHandoff:language:)` is the single entry point. Call it from a button action or trigger it automatically from your AI pipeline.

- If the user is not signed in, the login card appears automatically. Once they sign in, the call proceeds without requiring a second tap.
- The `contextHandoff` string is sent to the interpreter the moment they connect, so they arrive with full context.
- The SDK validates `language` against the languages available to the user before placing the call.

```swift
await masterWord.requestInterpreter(
    contextHandoff: "User asked about billing dispute on account #4821. AI could not resolve. Escalating.",
    language: selectedLanguage  // UserLanguage from fetchAvailableLanguages()
)
```

Observe `requestError` to surface failures in your own UI:

```swift
.onChange(of: masterWord.requestError) { _, error in
    if let error { showErrorAlert(error) }
}
// or use .alert directly:
.alert("Error", isPresented: Binding(
    get: { masterWord.requestError != nil },
    set: { if !$0 { masterWord.requestError = nil } }
)) {
    Button("OK") { masterWord.requestError = nil }
} message: {
    Text(masterWord.requestError ?? "")
}
```

---

## Language Selection

To validate the session language before placing a call, fetch the languages available to the authenticated user and present them for selection.

```swift
@State private var availableLanguages: [UserLanguage] = []
@State private var selectedLanguage: UserLanguage?

// Fetch after sign-in
let languages = try await masterWord.fetchAvailableLanguages()
availableLanguages = languages

// Present a picker using engName / nativeName
Picker("Language", selection: $selectedLanguage) {
    ForEach(availableLanguages, id: \.self) { language in
        Text(language.engName).tag(Optional(language))
    }
}

// Pass the selection when requesting — disable the button until a language is chosen
if let language = selectedLanguage {
    await masterWord.requestInterpreter(
        contextHandoff: summary,
        language: language
    )
}
```

If the selected language is no longer available at call time, `requestError` is set to `"Sorry, this language isn't available."` and no call is placed.

### Automatic escalation from an AI pipeline

In production the host app typically knows the session language from its AI context and triggers escalation programmatically — no user language selection needed. Cache the available languages once after sign-in, then match by name when escalating:

```swift
// On sign-in, cache the list once
.onChange(of: masterWord.authState) { _, state in
    if case .authenticated = state {
        Task {
            availableLanguages = (try? await masterWord.fetchAvailableLanguages()) ?? []
        }
    }
}

// Called by your AI pipeline when it decides to escalate
func escalateToInterpreter(detectedLanguage: String, summary: String) async {
    guard let language = availableLanguages.first(where: {
        $0.engName.localizedCaseInsensitiveCompare(detectedLanguage) == .orderedSame
    }) else { return }
    await masterWord.requestInterpreter(contextHandoff: summary, language: language)
}
```

### Gating the escalation button on language availability

Only show the "Request Human" button when a live interpreter is actually available for the session language. Resolve the matching `UserLanguage` as soon as the AI detects the language, and use its presence to drive button visibility:

```swift
@State private var availableLanguages: [UserLanguage] = []
@State private var sessionLanguage: UserLanguage? = nil  // set when AI detects the language

// Resolve once the AI identifies the language
func onLanguageDetected(_ detectedLanguage: String) {
    sessionLanguage = availableLanguages.first {
        $0.engName.localizedCaseInsensitiveCompare(detectedLanguage) == .orderedSame
    }
}

// Only render the button when the language is available
if let language = sessionLanguage {
    Button("Request Human Interpreter") {
        Task {
            await masterWord.requestInterpreter(
                contextHandoff: aiGeneratedSummary,
                language: language
            )
        }
    }
}
```

If `sessionLanguage` is nil — because the detected language has no interpreter coverage — the button simply does not appear. No error handling needed.

The SDK handles everything else automatically:

| Parameter | Value |
|---|---|
| Call type | Video (VRI) |
| Gender preference | No preference |
| Language ID | Resolved internally from the `UserLanguage` object |
| Authentication | Login card shown automatically if the session expired |
| Context delivery | Handoff string injected into the interpreter chat on connect |

---

## Testing

MasterWord will provide you with demo account credentials. Sign in with those credentials and use the **Zulu (test)** language to place a test call — a MasterWord team member will be standing by to answer as the interpreter.

Zulu test calls do not go through the live interpreter queue and will not generate a bill.

**The Zulu test language is only available in debug builds.** The SDK injects it automatically when your app is built with the `DEBUG` flag (the default for Xcode's Debug scheme). It will not appear in production builds.

Add a debug button to your app that fetches the language list and filters for the test entry:

```swift
#if DEBUG
Button("Test Call") {
    Task {
        let languages = (try? await masterWord.fetchAvailableLanguages()) ?? []
        guard let zulu = languages.first(where: { $0.engName == "Zulu (test)" }) else { return }
        await masterWord.requestInterpreter(
            contextHandoff: "Test call — SDK integration check.",
            language: zulu
        )
    }
}
#endif
```

Contact your MasterWord integration contact to schedule a test window so someone is available to answer.

