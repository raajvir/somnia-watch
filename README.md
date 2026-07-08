# Somnia — Apple Watch

A standalone (no iPhone companion required) watchOS app that paces a guided
breathing session with an animated circle and haptic taps, and reads heart
rate during the session via HealthKit.

## Project layout

```
somnia-watch/
├── project.yml                       XcodeGen spec (source of truth — the
│                                      .xcodeproj is generated, not committed)
├── README.md
└── SomniaWatch/
    ├── SomniaWatchApp.swift          App entry point + simple state-driven navigation
    ├── Config/BreathingConfig.swift  Timing constants (mirrors the phone app's constants/timing.ts)
    ├── Engine/BreathingEngine.swift  Pure breath-duration generator + phase-timeline math
    ├── Session/SessionController.swift  Wall-clock-anchored session driver (@MainActor ObservableObject)
    ├── Session/HapticPacer.swift     Maps breath phases to WKInterfaceDevice haptics
    ├── Sensors/WorkoutManager.swift  HKWorkoutSession + HKLiveWorkoutBuilder heart-rate reader
    ├── Views/HomeView.swift          Duration picker (8 / 12 min)
    ├── Views/SessionView.swift       Breathing circle, remaining time, heart rate, End button
    ├── Views/SummaryView.swift       Post-session recap
    └── Assets.xcassets               Accent color + (empty) app icon set
```

## Setup

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (tested with 2.45.4) and Xcode (tested with 26.6).

```sh
brew install xcodegen   # if you don't already have it
```

## Opening the project

The `.xcodeproj` is generated from `project.yml` and is **not** checked in.
Generate it before opening:

```sh
cd somnia-watch
xcodegen generate
open SomniaWatch.xcodeproj
```

Re-run `xcodegen generate` any time `project.yml` or the file layout changes.

## Running in the Simulator

From Xcode: select the `SomniaWatch` scheme, pick any Apple Watch simulator
as the run destination, and hit Run.

From the command line:

```sh
xcodegen generate
xcodebuild -project SomniaWatch.xcodeproj -scheme SomniaWatch \
  -destination 'generic/platform=watchOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

This repo builds with `CODE_SIGNING_ALLOWED=NO` so it compiles without an
Apple Developer team configured. To actually launch it in the Simulator
(rather than just compile it) or run on a physical Watch, build/run from
Xcode with a normal signing configuration instead.

### watchOS Simulator runtime

Compiling against `generic/platform=watchOS Simulator` only needs the watchOS
Simulator **SDK**, which ships with Xcode. Actually *booting* a simulator (to
run/debug, not just compile) needs the watchOS Simulator **runtime** as well.
Check what's installed with:

```sh
xcrun simctl list runtimes
```

If no `watchOS` line appears, install it via:

- Xcode → Settings → Components, or
- `xcodebuild -downloadPlatform watchOS`

(At the time this project was verified, no watchOS runtime was present until
`xcodebuild -downloadPlatform watchOS` was run, after which `xcrun simctl list
devices watchOS` showed several Apple Watch simulators ready to use.)

## Deploying via TestFlight

1. In Xcode, set a real Development Team under
   `SomniaWatch` target → Signing & Capabilities (the `project.yml` ships
   with `CODE_SIGNING_ALLOWED: NO` purely so CI/verification builds succeed
   without a team — flip signing back on for device/App Store builds).
2. Because this is a **standalone** watch app (`WKApplication: true`,
   `WKWatchOnly: true`, no iOS companion target), it can be archived and
   distributed on its own: **Product → Archive** with a Watch-capable
   destination, then use the Organizer to upload to App Store Connect.
3. In App Store Connect, add the build to a TestFlight group. Standalone
   watch apps are installed straight from the Watch app on the paired
   iPhone (App Store tab) — testers don't need to install anything on the
   phone itself first.
4. HealthKit note: `NSHealthShareUsageDescription` /
   `NSHealthUpdateUsageDescription` are already set in `project.yml`'s
   `info:` block, and `SomniaWatch/SomniaWatch.entitlements` declares the
   `com.apple.developer.healthkit` entitlement. Make sure HealthKit is
   enabled for the App ID in your Apple Developer account before archiving
   for TestFlight/App Store (the Simulator build in this repo works without
   it because `CODE_SIGNING_ALLOWED=NO` skips entitlement validation).

## Timing constants

`Config/BreathingConfig.swift` intentionally mirrors the phone app's
`constants/timing.ts` value-for-value (start/end breath duration, the
35/5/55/5 phase split, session lengths, wind-down). If either app's timing
changes, update both.
