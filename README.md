# MasterWord Embedded iOS SDK

Embed live interpreter access into your iOS app. The SDK handles authentication, provides a ready-made login UI, and connects users to a MasterWord interpreter on demand — including a context handoff so the interpreter is immediately up to speed.

---

## Requirements

- iOS 17.0+
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

## Bundled dependencies

The SDK binary includes **SignalRClient** and **Lottie** statically linked. Do not add either of these as separate dependencies in your own project — duplicate symbols will cause a linker error.

**TwilioVideo** and **TwilioVoice** are declared separately in the SDK's `Package.swift` and will be pulled in automatically when you add the package. Do not add them manually.

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

The SDK requests microphone access before placing any call, and camera access before video (VRI) calls. Add usage descriptions to your `Info.plist` or the system will deny access silently:

| Key | Example value |
|---|---|
| `NSCameraUsageDescription` | `"MasterWord needs camera access for video interpreter calls."` |
| `NSMicrophoneUsageDescription` | `"MasterWord needs microphone access for interpreter calls."` |

---

## Background Modes

Calls continue when the user presses the home button or switches apps. For video (VRI) calls the SDK automatically starts Picture in Picture (PiP) when the app is backgrounded, keeping the interpreter's video visible as a floating window; tapping the PiP window restores the call sheet exactly where it left off. For audio (OPI) calls the system green pill appears, and tapping it returns to the call UI.

Two background modes matter:

- **Audio, AirPlay, and Picture in Picture** (`audio`) — **required**. Without it iOS suspends the audio session on backgrounding, silently dropping the call.
- **Voice over IP** (`voip`) — **recommended for OPI**. With it, audio calls run through CallKit: they appear in the system call UI, survive backgrounding like phone calls, and support lock-screen mute/end. Without it the SDK automatically falls back to a direct in-app audio connection — calls still work but don't appear in the system call UI.

In Xcode, go to your target's **Signing & Capabilities** tab, click **+ Capability**, add **Background Modes**, and check both. Or add them directly to your `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

---

## Setup

Create a single `MasterWordSDK` instance at the root of your app, inject it into the environment, and apply `.masterWordSheet(sdk:)` to your root view. The modifier handles all SDK UI presentation automatically — the login card, the call screen, the post-call rating sheet, and the in-app "ongoing call" banner for minimized audio calls.

```swift
import SwiftUI
import MasterWordEmbedded

@main
struct YourApp: App {
    #if DEBUG
    @StateObject private var masterWord = MasterWordSDK(testLanguagesEnabled: true)
    #else
    @StateObject private var masterWord = MasterWordSDK()
    #endif

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

`requestInterpreter(type:contextHandoff:language:)` is the single entry point. Call it from a button action or trigger it automatically from your AI pipeline.

- `type` selects the session kind: `.vri` (video) or `.opi` (audio-only phone interpreting).
- If the user is not signed in, the login card appears automatically. Once they sign in, the call proceeds without requiring a second tap.
- The `contextHandoff` string is sent to the interpreter the moment they connect, so they arrive with full context.
- The SDK validates `language` against the languages available to the user before placing the call.

```swift
await masterWord.requestInterpreter(
    type: .vri,  // or .opi for audio-only
    contextHandoff: "User asked about billing dispute on account #4821. AI could not resolve. Escalating.",
    language: selectedLanguage  // UserLanguage from fetchAvailableLanguages()
)
```

### Session types

| Type | Session | Active call UI |
|---|---|---|
| `.vri` | Two-way video via Twilio room | Full-screen video, PiP support, chat overlay, camera-off placeholders |
| `.opi` | Audio-only voice call | Themed audio layout with always-visible chat, speaker toggle, and minimize |

OPI calls integrate with **CallKit** when your app declares the **Voice over IP** background mode, so the call shows in the system call UI and survives backgrounding like a phone call. Without the VoIP entitlement the SDK automatically falls back to a direct in-app audio connection — no configuration required, but the call will not appear in the system call UI.

Both session types display the interpreter's ID (e.g. "Interpreter 63461422") in the call UI once they connect — the same ID the interpreter announces verbally at session start for compliance. For CallKit-backed OPI calls it also appears in the system call UI and the Phone app's call history.

### Minimizing a call

The OPI call screen has a minimize button in the control bar (VRI uses Picture in Picture instead). Minimizing dismisses the SDK's call UI while the audio continues, returning the user to your app. While inside your app, the SDK shows a small green "Ongoing call" banner at the top of the screen — iOS only shows the system green pill once the app is backgrounded. Tapping either one returns to the call UI. `callState` stays `.active` throughout, and `showActiveCall()` is available if you need to re-present programmatically.

### Call state

`callState` exposes the full call lifecycle so you can build your own connecting/waiting UI instead of (or alongside) the SDK's default sheet:

| State | Meaning |
|---|---|
| `.idle` | No call in progress |
| `.connecting` | Authenticating and opening the SignalR hub |
| `.searching` | Waiting for an available interpreter |
| `.ringing` | Interpreter found, call ringing |
| `.accepted` | Interpreter accepted, connecting call media |
| `.active` | Session live |
| `.ending` | Hang-up sent, waiting for confirmation |

```swift
.onChange(of: masterWord.callState) { _, state in
    switch state {
    case .idle:        hideCustomConnectingUI()
    case .searching:   showWaitingAnimation()
    case .active:      hideCustomConnectingUI() // SDK sheet takes over
    default:           break
    }
}
```

The `masterWordSheet` modifier handles the active call UI automatically. Use `callState` if you want to drive your own connecting/loading experience before an interpreter connects.

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

## Theming

All SDK-presented UI — login, connecting, audio call, and rating — follows `MasterWordSDK.theme`. It defaults to `.light`; set it once at launch or bind it to your app's own appearance setting:

```swift
masterWord.theme = .dark    // .light (default) | .dark | .system
```

`.system` follows the device appearance. All call surfaces follow the theme, including the video call's controls and chat; the video feed itself is unaffected.

---

## Post-Call Rating

After a call that reached the live session ends, the SDK presents a rating sheet: a 1–5 star rating with an optional feedback field. **Submit** posts the rating to MasterWord; **Dismiss** sends nothing at all. The star rating is required to submit — feedback text alone cannot be sent.

The built-in sheet is on by default. To drive your own rating UI instead, disable it at init and use the public API:

```swift
@StateObject private var masterWord = MasterWordSDK(postCallRatingEnabled: false)

// lastIntakeId becomes non-nil when a completed call ends — observe it to show your UI
.onChange(of: masterWord.lastIntakeId) { _, intakeId in
    if intakeId != nil { showMyRatingUI = true }
}

// Submit from your own UI. If the user dismisses, simply don't call this.
try await masterWord.submitCallRating(4, notes: "Great interpreter")
```

`submitCallRating(_:notes:intakeId:)` defaults to the most recently completed call; pass `intakeId` explicitly to rate a specific session. Throws `TelemetryError.noCompletedCall` when there is no session to rate.

---

## Call Recording

Recordings are **controlled by account permissions** — most accounts don't have them enabled, and requesting one on such an account throws `RecordingError.notPermitted`. When the account is enabled, a recording is captured automatically for completed calls.

**Availability.** A recording is usually available within a few minutes of the call ending (`state` stays `.loading` until then). A call with no recording returns `RecordingError.notFound`.

To retrieve a recording, use **`RecordingRetriever`** — an `ObservableObject` that fetches it for you. Call `requestRecording(intakeId:)` **once**, then render `state`. There's no built-in recording screen.

```swift
@StateObject private var recording = RecordingRetriever()

Button("Get recording") { recording.requestRecording(intakeId: id) }
    .disabled(recording.state == .loading)

switch recording.state {
case .idle:            EmptyView()
case .loading:         ProgressView("Preparing…")   // retrieval in progress
case .ready(let a, let v):
    present(v ?? a)    // VRI → videoURL, OPI → audioURL
case .stillProcessing: Text("Not ready yet — try again later.")
case .notPermitted:    EmptyView()                  // account has no recording permission
case .notFound:        Text("No recording found for that call.")
case .failed:          Text("Couldn't retrieve the recording.")
}
```

- **When to call it:** once, from a button. Disable the control while `state == .loading`. The recording may not be ready immediately — `.loading` can persist for several minutes while it's prepared, then the retriever resolves to a terminal state on its own. If it lands on `.stillProcessing`, just call `requestRecording` again later. Keep the app foregrounded while it's working.
- **Which recording:** pass any `intakeId` — the most recent call is `masterWord.lastIntakeId`, or a specific past session's id from your own records.
- **The URLs are short-lived (~30 min) — don't cache them.** The `intakeId` is the durable handle: call `requestRecording` again for a fresh link rather than storing the URL, and keep those links out of logs and analytics.

### What the SDK stores, and what you own

The SDK does **not** keep a call history or persist recordings — that's the host app's responsibility. Knowing the split keeps the integration predictable:

- **The SDK remembers one id, briefly.** `masterWord.lastIntakeId` holds the intake id of the **most recent** call, in memory only. It's cleared when the app relaunches, and each new call overwrites it. It exists so you can fetch the recording (or submit a rating) for the call the user *just* finished, without tracking anything yourself.
- **To fetch a recording later, store the id yourself.** For any call beyond the current session's most recent, you need its `intakeId` — so capture and persist it. Observe `lastIntakeId`; when it becomes non-`nil` a call has just completed, and you can save that id in your own store alongside whatever metadata you need (date, language, service type, your own encounter reference). The SDK surfaces no other lookup.
- **The recording itself lives server-side; the `intakeId` is the key.** You don't have to download or store the media. Keep the `intakeId` and call `requestRecording` whenever you need it — a fresh, playable URL comes back each time. Download and retain your own copy only if you specifically need offline access or your own retained copy.

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
        type: .vri,
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
    await masterWord.requestInterpreter(type: .vri, contextHandoff: summary, language: language)
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
                type: .vri,
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
| Call type | `.vri` (video) or `.opi` (audio) — required argument |
| Gender preference | No preference |
| Language ID | Resolved internally from the `UserLanguage` object |
| Authentication | Login card shown automatically if the session expired |
| Context delivery | Handoff string injected into the interpreter chat on connect |

---

## Testing

MasterWord will provide you with demo account credentials. Sign in with those credentials and use the **Zulu (test)** language to place a test call — a MasterWord team member will be standing by to answer as the interpreter.

Zulu test calls do not go through the live interpreter queue and will not generate a bill.

**The Zulu test language requires `testLanguagesEnabled: true` in the SDK initializer.** Because the SDK is distributed as a pre-built binary, it cannot detect your app's build configuration at runtime. Pass the flag explicitly in your debug initializer (see Setup above) and it will never reach production.

Add a debug button to your app that fetches the language list and filters for the test entry:

```swift
#if DEBUG
Button("Test Call") {
    Task {
        let languages = (try? await masterWord.fetchAvailableLanguages()) ?? []
        guard let zulu = languages.first(where: { $0.engName == "Zulu (test)" }) else { return }
        await masterWord.requestInterpreter(
            type: .vri,
            contextHandoff: "Test call — SDK integration check.",
            language: zulu
        )
    }
}
#endif
```

Contact your MasterWord integration contact to schedule a test window so someone is available to answer.

---

## Migrating from 1.x

**New in 2.0:**

- **OPI (audio-only) sessions** via `requestInterpreter(type: .opi, ...)` — CallKit integration when the `voip` background mode is declared, with automatic in-app fallback when it isn't. Includes a minimize button, an in-app "ongoing call" banner, and automatic restore via the system green pill.
- **Theming** via `MasterWordSDK.theme` (`.light` default, `.dark`, `.system`) applied to all SDK UI, including a dark-mode connecting animation.
- **Post-call rating** — built-in star-rating sheet after completed calls, plus `lastIntakeId` and `submitCallRating(_:notes:intakeId:)` for host-driven rating UI.
- **TwilioVoice** is now a package dependency alongside TwilioVideo (resolved automatically).

**Breaking changes:**

- `requestInterpreter(contextHandoff:language:)` now requires a leading `type:` argument — pass `.vri` for the previous behavior.
- `VRICallState` and `VRIMessage` are renamed to `InterpreterCallState` and `InterpreterMessage`. Deprecated typealiases keep 1.x code compiling; update at your convenience.

**Behavior changes:**

- A post-call rating sheet appears after completed calls by default. Pass `postCallRatingEnabled: false` to the initializer to opt out.
- SDK UI defaults to light mode as before, but now respects `theme` if you set it.

