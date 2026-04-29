//
//  WorkoutLiveActivityManager.swift
//  Neural Loop
//
//  Created by Codex on 28/04/2026.
//

import ActivityKit
import Foundation

/// Manages the lifecycle of the workout Live Activity from the iOS app.
/// Start → Update → End, driven by the `ActiveWorkoutViewModel`.
@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private var currentActivityID: String?

    private init() {}

    // MARK: - Start

    /// Starts a new Live Activity for the given workout snapshot.
    func startActivity(snapshot: ActiveWorkoutSnapshot, restEndDate: Date? = nil, restTotalSeconds: Int? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("WorkoutLiveActivityManager: Live Activities not enabled")
            return
        }

        // End any existing activity first
        endActivity(dismissalPolicy: .immediate)

        let displayState = snapshot.displayState(restEndDate: restEndDate, restTotalSeconds: restTotalSeconds)

        let attributes = WorkoutActivityAttributes(
            sessionID: snapshot.session.id,
            workoutTitle: snapshot.title
        )

        let contentState = WorkoutActivityAttributes.ContentState(
            exerciseName: displayState.currentExerciseName,
            setNumber: displayState.currentSetNumber,
            totalSets: displayState.totalSets,
            targetReps: displayState.targetReps,
            completedReps: displayState.completedReps,
            weightKg: displayState.weightKg,
            restEndDate: displayState.restEndDate,
            restTotalSeconds: displayState.restTotalSeconds,
            progress: displayState.exerciseProgress,
            mode: displayState.mode
        )

        let content = ActivityContent(state: contentState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivityID = activity.id
            print("WorkoutLiveActivityManager: Started activity \(activity.id)")
        } catch {
            print("WorkoutLiveActivityManager: Failed to start activity: \(error)")
        }

        // Also persist for widget extension
        persistDisplayState(displayState)
    }

    // MARK: - Update

    /// Updates the running Live Activity with the latest workout state.
    func updateActivity(snapshot: ActiveWorkoutSnapshot, restEndDate: Date? = nil, restTotalSeconds: Int? = nil) {
        guard let activityID = currentActivityID else {
            // No active Live Activity — try starting one
            startActivity(snapshot: snapshot, restEndDate: restEndDate, restTotalSeconds: restTotalSeconds)
            return
        }

        let displayState = snapshot.displayState(restEndDate: restEndDate, restTotalSeconds: restTotalSeconds)

        let contentState = WorkoutActivityAttributes.ContentState(
            exerciseName: displayState.currentExerciseName,
            setNumber: displayState.currentSetNumber,
            totalSets: displayState.totalSets,
            targetReps: displayState.targetReps,
            completedReps: displayState.completedReps,
            weightKg: displayState.weightKg,
            restEndDate: displayState.restEndDate,
            restTotalSeconds: displayState.restTotalSeconds,
            progress: displayState.exerciseProgress,
            mode: displayState.mode
        )

        let content = ActivityContent(state: contentState, staleDate: nil)

        // Find the matching activity
        let activities = Activity<WorkoutActivityAttributes>.activities
        guard let activity = activities.first(where: { $0.id == activityID }) else {
            currentActivityID = nil
            startActivity(snapshot: snapshot, restEndDate: restEndDate, restTotalSeconds: restTotalSeconds)
            return
        }

        Task {
            await activity.update(content)
        }

        // Also persist for widget extension
        persistDisplayState(displayState)
    }

    // MARK: - End

    /// Ends the current Live Activity.
    func endActivity(finalSnapshot: ActiveWorkoutSnapshot? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        let activities = Activity<WorkoutActivityAttributes>.activities

        let finalState: WorkoutActivityAttributes.ContentState?
        if let finalSnapshot {
            let ds = finalSnapshot.displayState()
            finalState = WorkoutActivityAttributes.ContentState(
                exerciseName: ds.currentExerciseName,
                setNumber: ds.currentSetNumber,
                totalSets: ds.totalSets,
                targetReps: ds.targetReps,
                completedReps: ds.completedReps,
                weightKg: ds.weightKg,
                restEndDate: nil,
                restTotalSeconds: nil,
                progress: 1.0,
                mode: .finished
            )
        } else {
            finalState = nil
        }

        for activity in activities {
            Task {
                if let finalState {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: dismissalPolicy)
                } else {
                    await activity.end(nil, dismissalPolicy: dismissalPolicy)
                }
            }
        }

        currentActivityID = nil
        clearPersistedDisplayState()
    }

    // MARK: - Shared State Persistence

    private func persistDisplayState(_ state: WorkoutDisplayState) {
        guard let defaults = UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite) else { return }
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: WorkoutDisplayState.userDefaultsKey)
        } catch {
            print("WorkoutLiveActivityManager: Failed to persist display state: \(error)")
        }
    }

    private func clearPersistedDisplayState() {
        guard let defaults = UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite) else { return }
        defaults.removeObject(forKey: WorkoutDisplayState.userDefaultsKey)
    }
}
