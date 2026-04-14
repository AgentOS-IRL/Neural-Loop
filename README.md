# Neural Loop

Neural Loop is a multi-platform productivity suite that pairs a full featured iOS habit/goal/task experience with a lightweight WatchOS companion. The codebase is organized so that each major folder has its own README, and this document now points at that per-target documentation while explaining how the parts interact.

## Targets & their readiness
- `Neural Loop/` (iOS) – the main SwiftUI application hosting goals, habits, todos, calendar, settings, unified data orchestration, notification automation, and the custom Liquid Glass tab bar. See `Neural Loop/README.md` for a detailed breakdown of modules and responsibilities.
- `Neural Loop Watch Watch App/` (WatchOS) – a minimal counterpart that displays messages via watch connectivity and provides a send button for quick interactions. Refer to `Neural Loop Watch Watch App/README.md` for structure notes and connectivity guidance.
- `Shared/` – cross-target helpers such as `ConnectivityManager` that keep the iOS and Watch targets synchronized. `Shared/README.md` summarizes the shared architecture.
- `Neural LoopTests/` – the bundled test target for the `Neural Loop` scheme. Read `Neural LoopTests/README.md` to understand the current coverage and how to extend it.

## Architecture snapshot
- **Multi-target shell**: The iOS app contains the bulk of the UI and services, but shared managers expose consistent state to the Watch target. Each target can rely on the same `WCSession` plumbing without duplicating code because `Shared/ConnectivityManager.swift` is consumed by both.
- **Data & automation**: Supabase integration and local SwiftData models live in `database/` and `local_data/`, while `unified_data/` surfaces a single `UnifiedDataModel` instance to the entire UI. Smart scheduling lives under `ai_or_not/`, with `NotificationManager.swift` handling permission and delivery.
- **UI surface**: The five app tabs (goals, todo, habits, calendar, settings) route through `ContentView.swift` and `LiquidGlassTabBar`, while feature subfolders (`goal_screen/`, `habit_screen/`, `todo_screen/`, `calendar_view/`, `schedule/`) each document their role in `Neural Loop/README.md`.

## Getting started
1. Open `Neural Loop.xcodeproj` in Xcode 15 or later.
2. Ensure required Supabase credentials (if needed) are available to the app and any relevant scheme environment overrides are configured.
3. Use the `Neural Loop` scheme for iOS work or `Neural Loop Watch Watch App` for WatchOS.

## No Automated testing
-  No Tests in this project. 

## Related documentation
- `Neural Loop/README.md` (iOS target overview)
- `Neural Loop Watch Watch App/README.md` (Watch target overview)
- `Shared/README.md` (shared helpers and connectivity)
- `Neural LoopTests/README.md` (test target guidance)

