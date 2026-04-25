import Foundation

protocol WorkoutSessionFinalizing {
    func finalize(draft: ActiveWorkoutDraft) async throws
}

actor WorkoutSessionFinalizer: WorkoutSessionFinalizing {
    private let db: WorkoutDataManaging
    private let persistenceManager: WorkoutDraftPersistenceManager

    init(
        db: WorkoutDataManaging,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager()
    ) {
        self.db = db
        self.persistenceManager = persistenceManager
    }

    func finalize(draft: ActiveWorkoutDraft) async throws {
        // 1. Create session
        let sessionRequest = CreateWorkoutSessionRequest(
            date: draft.session.date,
            start_time: WorkoutTimeCoding.normalize(draft.session.start_time),
            end_time: WorkoutTimeCoding.string(from: Date()),
            session_type: draft.session.session_type,
            notes: draft.session.notes
        )
        let savedSession = try await db.createWorkoutSession(sessionRequest)
        
        // 2. Create sets or cardio logs
        for exerciseState in draft.exercises {
            for setDraft in exerciseState.sets {
                if exerciseState.exercise.isRepBased {
                    // Only save sets that have reps
                    let repsString = setDraft.repsText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let reps = Int(repsString), reps > 0 else { continue }
                    
                    let setRequest = CreateWorkoutSetRequest(
                        workout_session_id: savedSession.id ?? 0,
                        exercise_id: exerciseState.exercise.id,
                        set_number: setDraft.setNumber,
                        reps: reps,
                        weight: NumericFormatter.parse(setDraft.weightText),
                        superset_group_id: exerciseState.supersetGroupID
                    )
                    _ = try await db.createWorkoutSet(setRequest)
                } else if exerciseState.exercise.isDurationBased {
                    let duration = NumericFormatter.parse(setDraft.durationText) ?? 0
                    let distanceKM = NumericFormatter.parse(setDraft.distanceText)
                    let calories = NumericFormatter.parse(setDraft.caloriesText)

                    guard duration > 0 || (distanceKM ?? 0) > 0 || (calories ?? 0) > 0 else { continue }

                    let cardioRequest = CreateCardioLogRequest(
                        workout_session_id: savedSession.id ?? 0,
                        exercise_id: exerciseState.exercise.id,
                        distance_meters: distanceKM.map { $0 * 1000 },
                        duration_minutes: duration > 0 ? duration : nil,
                        calories: nil // FIXME: Restore once cardio_log.calories column is verified
                    )
                    _ = try await db.createCardioLog(cardioRequest)
                }
            }
        }
        
        // 3. Clear draft
        persistenceManager.clear(routineID: draft.routineID)
    }
}
