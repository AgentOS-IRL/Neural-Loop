# Neural Loop Watch Watch App

## Overview
This WatchKit target is the lightweight WatchOS companion that mirrors connectivity status and quick actions from the iOS app. It reuses `Shared/ConnectivityManager` to exchange messages and surface the latest payload coming from the iPhone.

## Key files
- `Neural_Loop_WatchApp.swift` – watch entry point that hosts `ContentView` in a `WindowGroup` scene.
- `ContentView.swift` – simple UI that renders the most recent message (`ConnectivityManager.shared.receivedMessage`) and offers a tap-to-send button for manual testing of the message channel.
- `Assets.xcassets` + `AppIcon.icon` – watch-specific branding assets for complications and alerts.

## Connectivity & shared state
- The watch UI depends entirely on `Shared/ConnectivityManager.swift`, which activates a `WCSession`, publishes `receivedMessage`, and exposes `sendMessage(_:)` so button taps can reach iOS. There is no bespoke state layer in this target beyond the published string.
- Watch-only views can safely tap `ConnectivityManager.shared` because the manager lives in `Shared/` and is referenced by both targets without duplication.

## Build & test guidance
- Use the `Neural Loop Watch Watch App` scheme in Xcode to build/run on a simulator or device.
- Automated verification is handled through the same `xcodebuild -scheme "Neural Loop" test` command that exercises shared code; the watch target itself is verified via this integrated workflow.

## Automation reminder
Testing stays automated. Do not add manual verification steps for the Watch target unless the automation layer explicitly requires them.

