# Neural Loop Watch App

## Overview

This target is the watchOS companion for Neural Loop. It presents a compact watch-first shell with Home and Fitness entry points, and the Fitness flow mirrors the active iPhone workout so sets can be reviewed and updated from Apple Watch.

The iPhone remains the authoritative source for workout data. The watch receives `ActiveWorkoutSnapshot` payloads through `Shared/ConnectivityManager.swift`, applies local optimistic edits for responsiveness, and sends `WorkoutWatchAction` payloads back to iOS for reconciliation.

## Key Files

- `Neural_Loop_WatchApp.swift` - watch app entry point. Creates the shared `WatchWorkoutStore` and injects it into the scene.
- `ContentView.swift` - top-level `NavigationStack` with Home and Fitness tiles. Home is currently a placeholder; Fitness opens the active workout experience.
- `WatchFitnessView.swift` - active workout container. Shows the current workout, disconnected and queued-action states, stale-workout handling, completion status, and the end-workout confirmation flow.
- `WatchWorkoutStore.swift` - watch-side state coordinator. Persists the latest snapshot, queues offline actions, applies optimistic updates, flushes queued actions when reachable, and reconciles with snapshots acknowledged by iOS.
- `WatchExerciseListView.swift` - exercise list rows with set progress and completion affordances.
- `WatchExerciseDetailView.swift` - per-exercise set list, add-set action, exercise completion toggle, and rest-timer presentation after completed sets.
- `WatchSetEntryView.swift` and `WatchSetEntryViewModel.swift` - set value editor for kg, reps, and completion state. Supports button controls and Digital Crown adjustments.
- `WatchRestTimerView.swift` and `WatchRestTimerViewModel.swift` - rest countdown shown after completing a set when the active exercise has a rest duration.
- `Shared/WorkoutWatchSyncModels.swift` - transport models shared by iOS and watchOS for snapshots, exercises, sets, and watch actions.
- `Shared/ConnectivityManager.swift` - shared `WCSession` wrapper for text messages, workout snapshots, workout actions, reachability, and clear-snapshot signaling.

## Runtime Flow

1. Starting or resuming a workout on iPhone maps the active draft into an `ActiveWorkoutSnapshot`.
2. iOS sends the snapshot through `ConnectivityManager.sendWorkoutSnapshot(_:)`.
3. The watch store observes `ConnectivityManager.shared.$lastSnapshot`, persists the snapshot, and renders it in `WatchFitnessView`.
4. Watch edits are converted into `WorkoutWatchAction` values:
   - update set kg/reps
   - toggle set completion
   - add a set
   - toggle exercise completion
   - finish workout
5. The watch applies actions optimistically, queues them in `UserDefaults`, and sends them to iOS when `WCSession` is reachable.
6. iOS applies each action to the active workout draft and sends a fresh snapshot with `lastProcessedActionID`.
7. The watch removes acknowledged actions from its queue, reapplies any remaining pending actions over the authoritative snapshot, and updates the UI.

## State And Persistence

- `WatchWorkoutStore.currentSnapshot` is the render source for the Fitness tab.
- The latest snapshot is stored under `com.neuralloop.watch.activeWorkoutSnapshot` so the watch can reopen into the last known workout state.
- Pending actions are stored under `com.neuralloop.watch.actionQueue` and retried when connectivity returns.
- `pendingActionCount` drives the queued-action indicator in the active workout view.
- Snapshots older than 24 hours are treated as stale and can be discarded from the watch.
- When iOS clears the active workout snapshot, the watch clears its local snapshot, pending queue, rest-timer coordination state, and finishing state.

## Connectivity Contract

- iOS sends `workoutSnapshot` messages to the watch.
- The watch sends `workoutAction` messages to iOS.
- Both sides use the shared `WorkoutSessionPointer` to ensure actions apply to the correct workout session.
- `lastProcessedActionID` is the acknowledgement mechanism for removing watch actions from the local queue.
- `clearWorkoutSnapshot()` only clears local published state; it does not send a separate `WCSession` message.

## Development Notes

- Keep watch UI small, glanceable, and optimized for short interactions.
- Add new sync fields to `Shared/WorkoutWatchSyncModels.swift` before using them in either target.
- Keep `WatchWorkoutStore` as the boundary between SwiftUI views and WatchConnectivity side effects.
- Preserve the optimistic-action and acknowledgement flow when changing set, exercise, or finish-workout behavior.
- Avoid iOS-only model imports in the watch target; map through shared transport structs instead.

## Build And Verification

- Use Xcode with the `Neural Loop Watch Watch App` scheme for simulator or device work.
- This repository's agent guidance says there are no tests to run for agent tasks. Do not run XCTest, `swift test`, shell regression tests, or other automated test commands unless a human explicitly asks for a specific command.
