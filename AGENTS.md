# AGENTS.md

## Project Overview

Neural Loop is an iOS-first SwiftUI productivity app with a lightweight watchOS companion. The app combines goals, habits, todos, task planning, fleeting notes, calendar views, notifications, audio mode, and settings into a single mobile workflow.

The repository also includes Supabase-backed data access, SwiftData local state, app-wide orchestration through `UnifiedDataModel`, shared WatchConnectivity helpers, deployment automation, and a local `CodexCore` Swift package.

## Repository Map

- `Neural Loop/` - Main iOS app target. Contains SwiftUI screens, app entry points, data orchestration, scheduling, notifications, audio mode, app utilities, and feature modules.
- `Neural Loop Watch Watch App/` - Lightweight watchOS companion target that uses shared connectivity to display and send simple messages.
- `Shared/` - Cross-target Swift code. Currently centered on `ConnectivityManager.swift` for `WCSession` setup and message delivery.
- `Packages/CodexCore/` - Local Swift package for Codex structured-tool support.
- `package_deploy.sh` - Helper script for archiving, installing, and launching the app on a configured physical iOS device.
- `Neural-Loop-Info.plist` - App configuration plist for the iOS target.

## Main App Structure

- `Neural Loop/Neural_LoopApp.swift` is the SwiftUI app entry point.
- `Neural Loop/ContentView.swift` composes the top-level navigation and custom tab experience.
- `Neural Loop/unified_data/` contains `UnifiedDataModel` and focused helpers for goals, tasks, habits, and fleeting notes.
- `Neural Loop/database/` contains Supabase integration, domain records, fetch/update helpers, tracking records, tags, and secret-loading support.
- `Neural Loop/local_data/` contains local SwiftData models used for device-side state.
- `Neural Loop/goal_screen/`, `habit_screen/`, `todo_screen/`, `task_screen/`, and `fleeting_notes/` contain the core productivity feature views and state helpers.
- `Neural Loop/calendar_view/` and `Neural Loop/utils/NeuralLoopCalendarService.swift` handle calendar display and calendar service integration.
- `Neural Loop/schedule/` contains reusable task timing, repeat, and scheduling controls.
- `Neural Loop/audio/` contains audio mode UI, transcription state, speech detection, and Codex coordination.
- `Neural Loop/NotificationManager.swift` and `Neural Loop/ai_or_not/auto_notification_scheduler/` handle reminder permissions, scheduling, and automation.
- `Neural Loop/tab_bar/` contains the custom app tab model and visual tab bar components.

## Watch And Shared Code

The watch target is intentionally small. `Neural Loop Watch Watch App/Neural_Loop_WatchApp.swift` hosts the watch UI, while watch `ContentView.swift` reads from `ConnectivityManager.shared` and can send a simple message back to iOS.

`Shared/ConnectivityManager.swift` centralizes WatchConnectivity setup, session activation, published message state, and message sending so the iOS and watchOS targets do not duplicate `WCSession` plumbing.

## Data And Configuration

Supabase integration lives under `Neural Loop/database/`. Publishable client configuration is in `SupabaseUltis.swift`; secret metadata and loading behavior are represented in `Secrets.swift`.

LLM and audio-related features depend on configured secret rows such as `codex_auth_token` and `chatgpt_account_id`. Do not commit private credential values, local tokens, or personal account secrets to this repository.

## Development Notes

- Prefer existing SwiftUI patterns and local helpers before introducing new abstractions.
- Keep feature changes scoped to the relevant folder and shared model/helper files.
- Preserve the app's existing tab structure, shared `UnifiedDataModel` flow, Supabase access patterns, and WatchConnectivity singleton unless a task explicitly calls for a larger redesign.
- Use Xcode for app and watch target work. The main project file is `Neural Loop.xcodeproj`.
- The local package declares Swift tools version 6.0 and supports iOS 16 and macOS 13.
- `package_deploy.sh` is device-specific because it contains a configured physical-device UDID. Update that value intentionally if deployment behavior changes.

## Testing Guidance

There are no tests to be run in this repo for agent tasks. Do not run XCTest, `swift test`, shell regression tests, or other automated test commands unless a human explicitly asks for a specific command.

When finishing a change, state that tests were not run because this repository's agent guidance says there are no tests to run.
