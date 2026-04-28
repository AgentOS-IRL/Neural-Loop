# Neural Loop (iOS target)

## Overview
Neural Loop is the primary SwiftUI target that powers the iPhone experience. It stitches together goals, habits, tasks, and calendar views into a single unified destination, orchestrating Supabase-backed storage, local SwiftData models, and a custom tab bar so the mobile UI stays responsive while syncing smart scheduling rules in the background.

## Key modules
- **App entry & navigation** – `Neural_LoopApp.swift` bootstraps the app, requests calendar access, registers `CompletedRecurringTask` in SwiftData, and injects `UnifiedDataModel.shared`. `ContentView.swift` wires the `AppTab` enum, custom `LiquidGlassTabBar`, and the five main tabs (goals, tasks, notes, calendar, settings), with the tasks tab opening the merged hub for todo and habits and the notes tab rendering the Supabase-backed fleeting-notes feed.
- **Goals, habits, todos** – `goal_screen/`, `habit_screen/`, `todo_screen/`, and `task_screen/` contain the SwiftUI views, sheet helpers, and progress components for creating, editing, and inspecting records. Subfolders like `add_edit_pages/`, `goal_progress/`, `ProgressHistory.swift`, and `ProgressChartView.swift` keep each workflow focused.
- **Calendar & schedule controls** – `calendar_view/` implements `CalendarDayView`, `TimeGridView`, event overlays, and helper utilities (time/bar views + `NeuralLoopCalendarService.swift` from `utils/`) so calendar rendering stays decoupled from domain logic. `schedule/` supplies reusable `TimeRuleSheet`, `RepeatRuleSheet`, and task scheduling models shared by habit/goal stacks.
- **Data layer** – `database/` houses Supabase integration (`DBManager.swift`, `SupabaseUltis.swift`), domain models (`Goals.swift`, `Habits.swift`, `Tasks.swift`, `LifeAreas.swift`), and derived helpers (`GoalsTracking.*`, `TasksAndTagsUtils.swift`). `unified_data/` encapsulates `UnifiedDataModel` plus `GoalsUDM`, `HabitsUDM`, `TasksUDM` so UI controls access to a single source of truth while syncing across views.
- **Automation helpers** – `ai_or_not/auto_notification_scheduler/` contains notification and habit scheduling helpers, which compute reminder windows before handing off scheduling to `NotificationManager.swift`. `NotificationManager` centralizes permission, logging, and one-off/repeating notification creation. `tab_bar/` defines `LiquidGlassTabBar`, `GlassTabItem`, and `AppTab` so the visual chrome stays modular, while `task_screen/TaskHubView.swift` hosts the merged todo/habit destination and its secondary selector.
- **Utilities & local state** – `utils/` collects chart helpers, color extensions, selection sheets, and `NeuralLoopCalendarService`. `local_data/CompletedRecursiveTask.swift` and `models/Base.swift` keep local model scaffolding tidy.

## Integration & shared services
- The iOS target holds most of the business logic, but it also consumes `Shared/ConnectivityManager.swift` to mirror watch connectivity events (messages, state) via `@MainActor` updates.
- `UnifiedDataModel` feeds the `ContentView` screens, while `NotificationManager` and `NeuralLoopCalendarService` provide side effects (notifications, calendar creation) triggered by the feature screens.

## Build & test guidance
1. Open `Neural Loop.xcodeproj` in Xcode 15+.
2. Select the `Neural Loop` scheme to run the iOS target and its associated tests.
3. Prefer `xcodebuild -scheme "Neural Loop" test` (or the Xcode test button) for automated verification; no manual QA passes are required.

## Automation reminder
This folder follows the project-wide rule: rely on automated tests (`Neural Loop` scheme). Manual verification is out of scope for now.

## Related documentation
- Root overview: `../README.md`
- Watch companion: `../Neural Loop Watch Watch App/README.md`
- Shared helpers: `../Shared/README.md`
