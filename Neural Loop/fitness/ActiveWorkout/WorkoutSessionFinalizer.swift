import Foundation

@MainActor
protocol WorkoutSessionFinalizing {
    func finalize(draft: ActiveWorkoutDraft) async throws
}

@MainActor
final class WorkoutSessionFinalizer: WorkoutSessionFinalizing {
    private let db: any WorkoutFinalizationPersisting
    private let persistenceManager: WorkoutDraftPersistenceManager

    init(
        db: any WorkoutFinalizationPersisting,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager()
    ) {
        self.db = db
        self.persistenceManager = persistenceManager
    }

    func finalize(draft: ActiveWorkoutDraft) async throws {
        let payload = FinalizeWorkoutPayload(
            routine_id: draft.routineID,
            session: FinalizeWorkoutSessionPayload(
                date: WorkoutDateCoding.string(from: draft.session.date),
                start_time: WorkoutTimeCoding.normalize(draft.session.start_time),
                end_time: WorkoutTimeCoding.string(from: Date()),
                session_type: draft.session.session_type,
                notes: draft.session.notes
            ),
            sets: strengthSets(from: draft),
            cardio_logs: cardioLogs(from: draft)
        )

        _ = try await db.finalizeWorkout(payload)
        persistenceManager.clear(routineID: draft.routineID)
    }

    private func strengthSets(from draft: ActiveWorkoutDraft) -> [FinalizeWorkoutSetPayload] {
        draft.exercises.flatMap { exercise -> [FinalizeWorkoutSetPayload] in
            guard exercise.exercise.isRepBased else { return [] }

            return exercise.sets.compactMap { set in
                guard set.isCompleted,
                      let reps = Int(set.repsText.trimmingCharacters(in: .whitespacesAndNewlines)),
                      reps > 0 else { return nil }

                return FinalizeWorkoutSetPayload(
                    exercise_id: exercise.exercise.id,
                    routine_exercise_id: exercise.id > 0 ? exercise.id : nil,
                    set_type: set.setType,
                    set_number: set.setNumber,
                    reps: reps,
                    weight: NumericFormatter.parse(set.weightText),
                    superset_group_id: exercise.supersetGroupID
                )
            }
        }
    }

    private func cardioLogs(from draft: ActiveWorkoutDraft) -> [FinalizeWorkoutCardioPayload] {
        draft.exercises.flatMap { exercise -> [FinalizeWorkoutCardioPayload] in
            guard exercise.exercise.isDurationBased else { return [] }

            return exercise.sets.compactMap { set in
                guard set.isCompleted else { return nil }
                let duration = NumericFormatter.parse(set.durationText)
                let distanceKilometers = NumericFormatter.parse(set.distanceText)
                let calories = NumericFormatter.parse(set.caloriesText)
                guard (duration ?? 0) > 0 || (distanceKilometers ?? 0) > 0 || (calories ?? 0) > 0 else {
                    return nil
                }

                return FinalizeWorkoutCardioPayload(
                    exercise_id: exercise.exercise.id,
                    routine_exercise_id: exercise.id > 0 ? exercise.id : nil,
                    set_number: set.setNumber,
                    distance_meters: distanceKilometers.map { $0 * 1000 },
                    duration_minutes: duration,
                    calories: calories
                )
            }
        }
    }
}
