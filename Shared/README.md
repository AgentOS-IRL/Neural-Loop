# Shared

## Overview
`Shared` contains cross-target helpers that both the iOS app and the Watch app rely on. Currently it only holds `ConnectivityManager.swift`, which centralizes watch connectivity logic and keeps the session live for the entire app lifecycle.

## Key file
- `ConnectivityManager.swift` – a singleton `WCSessionDelegate` that publishes the latest message string, logs activation, handles reactivation on iOS, and exposes `sendMessage(_:)`. It works in `@MainActor` contexts so SwiftUI views can subscribe via `@StateObject` or `@ObservedObject` and react instantly.

## How it fits in the stack
- The iOS `ContentView` and Watch `ContentView` both read from the same shared manager, ensuring messages are mirrored without code duplication.
- Because the manager lives in Swift shared code, both targets can add additional watch connectivity behaviors (e.g., started data transfers) without introducing another copy of the `WCSession` plumbing.

## Build & Testing guidance
- This code is covered by the `Neural Loop` scheme; run `xcodebuild -scheme "Neural Loop" test` to verify the shared behavior in automated suites (even if the tests are empty fixtures for now).

## Automation reminder
Manual verification is not required. Keep relying on the automated test scheme for any future changes to the shared layer.

