# Neural Loop

Neural Loop is a comprehensive productivity and habit-tracking application designed to bridge the gap between long-term goals, daily habits, and immediate tasks. Built with SwiftUI and powered by Supabase, it provides a seamless experience across iOS and Apple Watch.

## Key Features

- **Unified Dashboard:** A central hub to manage Goals, Habits, and Tasks in one place.
- **Goal Management:** 
  - Define long-term objectives and organize them into "Life Areas".
  - Track progress with dedicated goal detail views.
- **Habit Tracking:**
  - Monitor daily and weekly routines.
  - Visualize progress through interactive charts (Bar and Line charts).
  - Habit-specific rule sheets for flexible scheduling.
- **Task Management (Todo):**
  - Categorize tasks using a flexible tagging system.
  - Schedule tasks with recurrence rules.
- **Interactive Calendar:**
  - Integrated calendar view using `EventKit`.
  - Visualize tasks and habit occurrences alongside system calendar events.
- **Smart Scheduling (Auto-Notifications):**
  - Intelligent notification system that dynamically schedules reminders.
  - Example: **Water Auto-Scheduler** that plans reminders around meal times and enforces minimum intervals.
- **Multi-platform Support:** 
  - Full-featured iOS application.
  - Native WatchOS companion app for quick updates and notifications.
- **Cloud Synchronization:** Real-time data persistence and sync across devices via Supabase.

## Project Structure

The project follows a modular structure organized by features and core functionality:

- **`Neural Loop/`**: Primary iOS application source.
  - **`ContentView.swift`**: Main navigation entry point using a custom `LiquidGlass` tab bar.
  - **`database/`**: Data models (Goals, Habits, Tasks) and Supabase integration logic (`DBManager`, `SupabaseUltis`).
  - **`unified_data/`**: The central `UnifiedDataModel` which acts as the application's source of truth and handles data orchestration.
  - **`goal_screen/`**: UI components for goal creation, editing, and progress tracking.
  - **`habit_screen/`**: UI for habit management and progress visualization.
  - **`todo_screen/`**: Task management interface.
  - **`calendar_view/`**: Custom calendar implementation including time grids and event overlays.
  - **`ai_or_not/`**: "Smart" logic for automatic notification scheduling and habit optimization.
  - **`schedule/`**: Shared scheduling UI components (Time rules, Repeat rules).
  - **`tab_bar/`**: Implementation of the custom animated `LiquidGlassTabBar`.
- **`Neural Loop Watch Watch App/`**: Source code for the Apple Watch companion application.
- **`Shared/`**: Logic and managers (e.g., `ConnectivityManager`) shared between iOS and WatchOS.
- **`Neural Loop.xcodeproj`**: Xcode project configuration and workspace settings.

## Technology Stack

- **Language:** Swift 6.0
- **Framework:** SwiftUI
- **Local Storage:** SwiftData (for local cache and specific records)
- **Backend:** Supabase (PostgreSQL, Authentication, Real-time)
- **System Integration:** EventKit (Calendar), UserNotifications
- **Architecture:** MVVM with a Unified Data Model (UDM) approach.

## Getting Started

1. Open `Neural Loop.xcodeproj` in Xcode 15 or later.
2. Ensure you have the necessary Supabase environment variables configured (if applicable).
3. Select the `Neural Loop` target for iOS or `Neural Loop Watch Watch App` for WatchOS.
4. Build and Run.

---
Created by Sanjeev Hayal
