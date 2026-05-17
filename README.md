# Neural Loop

Neural Loop is an iOS-first SwiftUI productivity app with a lightweight watchOS companion. The app brings goals, habits, todos, task planning, fleeting notes, calendar views, notifications, AI mode, and settings into one mobile workflow.

The repository also includes the supporting systems around that app: Supabase-backed data access, SwiftData local state, app-level data orchestration through `UnifiedDataModel`, shared WatchConnectivity helpers, shell deployment automation, and the local `CodexCore` Swift package for structured-tool support.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `Neural Loop/` | Main iOS target with the SwiftUI app, feature screens, data layer, scheduling, notifications, AI mode, and app utilities. |
| `Neural Loop Watch Watch App/` | watchOS companion target that uses shared connectivity to exchange simple messages with the iOS app. |
| `Shared/` | Cross-target code, currently centered on `ConnectivityManager.swift` for `WCSession` setup and message delivery. |
| `Neural LoopTests/` | XCTest target for app logic, UI-state helpers, navigation behavior, AI transcription state, secrets loading, formatting, and database-facing helpers. |
| `Packages/CodexCore/` | Local Swift package with independent source and test targets for Codex structured-tool support. |
| `tests/` | Shell-level regression tests, including deployment-script coverage. |
| `package_deploy.sh` | Archive, install, and launch helper for a configured physical iOS device. |

## Project Components

### iOS App Target

`Neural Loop/Neural_LoopApp.swift` is the SwiftUI app entry point. It prepares app services, registers local SwiftData models, and injects shared data into the UI.

`Neural Loop/ContentView.swift` composes the top-level navigation and tab experience. Feature folders under `Neural Loop/` cover goals, tasks, todos, habits, calendar, fleeting notes, AI mode, scheduling, and settings.

### Watch App Target

`Neural Loop Watch Watch App/Neural_Loop_WatchApp.swift` is the watchOS entry point. The watch UI is intentionally small: it displays the latest connectivity message and exposes a quick send action through the shared manager.

### Shared Code

`Shared/ConnectivityManager.swift` centralizes `WCSession` activation, message publishing, and send helpers so iOS and watchOS targets do not duplicate connectivity plumbing.

### CodexCore Package

`Packages/CodexCore/` is a local Swift package with its own `Package.swift`, library target, and XCTest target. It can be verified independently with `swift test`.

## Architecture Snapshot

- `unified_data/` exposes `UnifiedDataModel` as the app-level source of truth for Supabase-loaded domain data, with focused helpers for goals, tasks, habits, and fleeting notes.
- `database/` contains Supabase clients, domain records, fetch/update helpers, tags, tracking records, and secret metadata.
- `local_data/` contains local SwiftData models used for device-side state.
- `schedule/` contains task timing, repeat, and scheduling controls shared by feature flows.
- `NotificationManager.swift` and `ai_or_not/auto_notification_scheduler/` handle reminder permissions, scheduling, and automation.
- `ai/` contains AI mode presentation, speech detection/transcription state, and Codex coordination.
- `tab_bar/` contains the custom tab chrome and app tab model.
- `Shared/ConnectivityManager.swift` handles iOS/watchOS communication through WatchConnectivity.

## Getting Started

Required tools:

- Xcode 15 or later for the app and watchOS targets.
- A Swift toolchain compatible with `Packages/CodexCore/Package.swift`, which currently declares `swift-tools-version: 6.0`.

Open `Neural Loop.xcodeproj` in Xcode. Use the `Neural Loop` scheme for iOS development and app tests. Use the `Neural Loop Watch Watch App` scheme for watchOS companion work when that scheme is available in Xcode.

Resolve Swift package dependencies through Xcode for app work. For the standalone package, run commands from `Packages/CodexCore/`.

## Configuration

Supabase integration lives under `Neural Loop/database/`. Publishable Supabase client configuration is defined in `SupabaseUltis.swift`, while secret metadata and loading behavior are represented in `Secrets.swift`.

LLM and AI-related features depend on configured secret rows such as `codex_auth_token` and `chatgpt_account_id`. Do not commit private credential values or personal tokens to this repository.

## Automated Testing

Manual verification is not required for this documentation task. Use automated checks for future documentation-adjacent changes that touch scripts, packages, or app-facing assumptions.

Recommended commands:

```bash
xcodebuild -project "Neural Loop.xcodeproj" -scheme "Neural Loop" test
```

```bash
cd Packages/CodexCore && swift test
```

```bash
bash tests/package_deploy_test.sh
```

If Xcode requires a simulator destination on a given machine, pass an appropriate `-destination` for an installed iOS simulator.

## Deployment Helper

`package_deploy.sh` archives the `Neural Loop` scheme, checks for a configured physical device, installs the built app with `xcrun devicectl`, and launches the bundle on that device.

The script is device-specific because `DEVICE_UDID` is hard-coded. Update that value intentionally for a different device instead of treating the script as a generic release pipeline.

Automated regression coverage for the script lives in `tests/package_deploy_test.sh`.

## Related Documentation

- `Neural Loop/README.md` - iOS target overview.
- `Neural Loop Watch Watch App/README.md` - watchOS target overview.
- `Shared/README.md` - shared connectivity helpers.
- `Neural LoopTests/README.md` - XCTest target overview.
- `Packages/CodexCore/README.md` - CodexCore package test command.
