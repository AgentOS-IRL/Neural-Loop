import Foundation

enum WatchWorkoutSnapshotReconciliation {
    case ignored
    case accepted(snapshot: ActiveWorkoutSnapshot, pendingActions: [WorkoutWatchAction])
}

enum WatchWorkoutSnapshotReducer {
    static func applying(
        _ action: WorkoutWatchAction,
        to snapshot: ActiveWorkoutSnapshot
    ) -> ActiveWorkoutSnapshot {
        var snapshot = snapshot

        switch action.payload {
        case .updateSetValues(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }),
               let setIndex = snapshot.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == action.reference.setID }) {
                if let kg = action.values.kg {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.kg = kg
                }
                if let reps = action.values.reps {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.reps = reps
                }
                if let duration = action.values.durationMinutes {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.durationMinutes = duration
                }
                if let distance = action.values.distanceKilometers {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.distanceKilometers = distance
                }
                if let calories = action.values.calories {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.calories = calories
                }
            }

        case .toggleSetCompletion(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }),
               let setIndex = snapshot.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == action.reference.setID }) {
                if action.isCompleted {
                    let exercise = snapshot.exercises[exerciseIndex]
                    let values = exercise.sets[setIndex].values
                    if exercise.isDurationBased == true {
                        guard (values.durationMinutes ?? 0) > 0
                            || (values.distanceKilometers ?? 0) > 0
                            || (values.calories ?? 0) > 0 else { return snapshot }
                    } else {
                        guard (values.reps ?? 0) > 0 else { return snapshot }
                    }
                }
                snapshot.exercises[exerciseIndex].sets[setIndex].isCompleted = action.isCompleted
            }

        case .addSet(let reference):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == reference.exerciseID }) {
                let nextNumber = (snapshot.exercises[exerciseIndex].sets
                    .filter { ($0.setType ?? .working) == .working }
                    .map(\.setNumber)
                    .max() ?? 0) + 1
                snapshot.exercises[exerciseIndex].sets.append(
                    SetSnapshot(
                        id: action.id.uuidString,
                        setNumber: nextNumber,
                        values: WorkoutSetValuesSnapshot(),
                        isCompleted: false,
                        setType: .working
                    )
                )
            }

        case .updateExerciseCompletion(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }) {
                if action.isCompleted {
                    let exercise = snapshot.exercises[exerciseIndex]
                    let hasEmptySet = exercise.sets.contains { set in
                        if exercise.isDurationBased == true {
                            return (set.values.durationMinutes ?? 0) <= 0
                                && (set.values.distanceKilometers ?? 0) <= 0
                                && (set.values.calories ?? 0) <= 0
                        }
                        return (set.values.reps ?? 0) <= 0
                    }
                    guard !hasEmptySet else { return snapshot }
                }
                snapshot.exercises[exerciseIndex].isCompleted = action.isCompleted
                for index in snapshot.exercises[exerciseIndex].sets.indices {
                    snapshot.exercises[exerciseIndex].sets[index].isCompleted = action.isCompleted
                }
            }

        case .cancelRestTimer:
            snapshot.restEndDate = nil
            snapshot.restTotalSeconds = nil

        default:
            break
        }

        return snapshot
    }

    static func reconcile(
        current: ActiveWorkoutSnapshot?,
        authoritative: ActiveWorkoutSnapshot,
        pendingActions: [WorkoutWatchAction]
    ) -> WatchWorkoutSnapshotReconciliation {
        if let current, current.session.id != authoritative.session.id {
            return .accepted(snapshot: authoritative, pendingActions: [])
        }

        if let current, authoritative.revision < current.revision {
            return .ignored
        }

        let remaining = pendingActions.filter {
            $0.sequence > authoritative.lastProcessedWatchSequence
        }
        let reconciled = remaining.reduce(authoritative) { snapshot, action in
            applying(action, to: snapshot)
        }
        return .accepted(snapshot: reconciled, pendingActions: remaining)
    }
}
