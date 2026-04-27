import Foundation

nonisolated extension ActiveWorkoutDraft {
    func watchSnapshot(now: Date = Date(), lastProcessedActionID: UUID? = nil) -> ActiveWorkoutSnapshot {
        let sessionPointer = watchSessionPointer

        return ActiveWorkoutSnapshot(
            session: sessionPointer,
            title: session.session_type,
            startedAt: createdAt,
            elapsedSeconds: max(0, Int(now.timeIntervalSince(createdAt))),
            exercises: exercises.enumerated().map { index, exercise in
                exercise.watchSnapshot(orderIndex: index)
            },
            lastProcessedActionID: lastProcessedActionID,
            timestamp: now,
            revision: revision,
            generatedAt: now,
            lastProcessedWatchSequence: lastProcessedWatchSequence
        )
    }

    var watchSessionPointer: WorkoutSessionPointer {
        WorkoutSessionPointer(
            id: "active-workout-\(routineID)-\(createdAt.timeIntervalSince1970)",
            routineID: routineID,
            workoutSessionID: session.id
        )
    }
}

extension WorkoutDraftPersistenceManager {
    func watchSnapshot(routineID: Int64, now: Date = Date()) -> ActiveWorkoutSnapshot? {
        load(routineID: routineID)?.watchSnapshot(now: now)
    }
}

private extension WorkoutExerciseCardState {
    func watchSnapshot(orderIndex: Int) -> ExerciseSnapshot {
        ExerciseSnapshot(
            id: watchExerciseID(orderIndex: orderIndex),
            sourceExerciseID: exercise.id,
            routineExerciseID: id,  // WorkoutExerciseCardState.id — the routine exercise ID
            name: exercise.name,
            orderIndex: orderIndex,
            restDurationSeconds: watchRestDurationSeconds,
            isCompleted: watchIsCompleted,
            sets: sets.map { $0.watchSnapshot() }
        )
    }

    var watchIsCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy(\.isCompleted)
    }

    var watchRestDurationSeconds: Int? {
        guard let restSeconds, restSeconds > 0 else { return nil }
        return restSeconds
    }

    func watchExerciseID(orderIndex: Int) -> String {
        if id != 0 {
            return "routine-exercise-\(id)"
        }

        return "exercise-\(exercise.id)-\(orderIndex)"
    }
}

private extension WorkoutSetDraft {
    func watchSnapshot() -> SetSnapshot {
        let draftID = id.uuidString

        return SetSnapshot(
            id: draftID,
            sourceSetID: draftID,
            setNumber: setNumber,
            values: WorkoutSetValuesSnapshot(
                kg: NumericFormatter.parse(weightText),
                reps: repsText.watchRepsValue
            ),
            isCompleted: isCompleted
        )
    }
}

private extension String {
    var watchRepsValue: Int? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }
}
