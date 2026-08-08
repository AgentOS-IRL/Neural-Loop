import Foundation
import Supabase

extension DBManager {
    private var workoutSessionTableName: String { "workout_session" }
    private var workoutSetTableName: String { "workout_set" }
    private var cardioLogTableName: String { "cardio_log" }

    // MARK: - Workout Sessions

    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        let inserted: [WorkoutSession] = try await customsupabase
            .from(workoutSessionTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let session = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return session
    }

    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        try await customsupabase
            .from(workoutSessionTableName)
            .select()
            .order("date", ascending: false)
            .order("id", ascending: false)
            .execute()
            .value
    }

    func fetchWorkoutSession(by id: Int64) async throws -> WorkoutSession? {
        let rows: [WorkoutSession] = try await customsupabase
            .from(workoutSessionTableName)
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchWorkoutSessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        try await customsupabase
            .from(workoutSessionTableName)
            .select()
            .gte("date", value: WorkoutDateCoding.string(from: from))
            .lte("date", value: WorkoutDateCoding.string(from: to))
            .order("date", ascending: false)
            .order("id", ascending: false)
            .execute()
            .value
    }

    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession {
        guard let id = session.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateWorkoutSessionRequest(
            date: session.date,
            start_time: session.start_time,
            end_time: session.end_time,
            session_type: session.session_type,
            notes: session.notes
        )
        let updated: [WorkoutSession] = try await customsupabase
            .from(workoutSessionTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let session = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return session
    }

    func deleteWorkoutSession(id: Int64) async throws {
        try await customsupabase
            .from(workoutSessionTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Workout Sets

    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        let inserted: [WorkoutSet] = try await customsupabase
            .from(workoutSetTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let set = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return set
    }

    func fetchWorkoutSets(sessionId: Int64) async throws -> [WorkoutSet] {
        try await customsupabase
            .from(workoutSetTableName)
            .select()
            .eq("workout_session_id", value: Int(sessionId))
            .order("set_type", ascending: true)
            .order("set_number", ascending: true)
            .order("id", ascending: true)
            .execute()
            .value
    }

    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] {
        try await customsupabase
            .from(workoutSetTableName)
            .select()
            .eq("exercise_id", value: Int(exerciseId))
            .order("id", ascending: true)
            .execute()
            .value
    }

    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet {
        guard let id = set.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateWorkoutSetRequest(
            workout_session_id: set.workout_session_id,
            exercise_id: set.exercise_id,
            set_number: set.set_number,
            reps: set.reps,
            weight: set.weight,
            superset_group_id: set.superset_group_id,
            routine_exercise_id: set.routine_exercise_id,
            set_type: set.set_type
        )
        let updated: [WorkoutSet] = try await customsupabase
            .from(workoutSetTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let set = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return set
    }

    func deleteWorkoutSet(id: Int64) async throws {
        try await customsupabase
            .from(workoutSetTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Cardio Logs

    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        let inserted: [CardioLog] = try await customsupabase
            .from(cardioLogTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let log = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return log
    }

    func fetchCardioLogs(sessionId: Int64) async throws -> [CardioLog] {
        try await customsupabase
            .from(cardioLogTableName)
            .select()
            .eq("workout_session_id", value: Int(sessionId))
            .order("id", ascending: true)
            .execute()
            .value
    }

    func fetchCardioLogs(exerciseId: Int64) async throws -> [CardioLog] {
        try await customsupabase
            .from(cardioLogTableName)
            .select()
            .eq("exercise_id", value: Int(exerciseId))
            .order("id", ascending: true)
            .execute()
            .value
    }

    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog {
        guard let id = log.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateCardioLogRequest(
            workout_session_id: log.workout_session_id,
            exercise_id: log.exercise_id,
            distance_meters: log.distance_meters,
            duration_minutes: log.duration_minutes,
            calories: log.calories,
            routine_exercise_id: log.routine_exercise_id,
            set_number: log.set_number
        )
        let updated: [CardioLog] = try await customsupabase
            .from(cardioLogTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let log = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return log
    }

    func deleteCardioLog(id: Int64) async throws {
        try await customsupabase
            .from(cardioLogTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    /// Executes the `get_workout_session_detail` RPC.
    /// Expected JSON return structure (mapped to `WorkoutSessionDetail`):
    /// {
    ///   "session": { ...WorkoutSession fields... },
    ///   "exercises": [
    ///     {
    ///       "exerciseId": 1,
    ///       "exerciseName": "Bench Press",
    ///       "exerciseType": "rep_based",
    ///       "sets": [{ ...WorkoutSet fields... }],
    ///       "cardioLogs": [{ ...CardioLog fields... }]
    ///     }
    ///   ]
    /// }
    /// Fetches one workout session with its related workout sets/cardio logs.
    /// - Parameter sessionId: workout session ID.
    /// - Returns: A JSON object containing workout session details.
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail {
        try await customsupabase
            .rpc("get_workout_session_detail", params: ["p_session_id": sessionId])
            .execute()
            .value
    }

    /// Executes the `get_fitness_analysis_summary` RPC.
    /// Expected JSON return structure (mapped to `FitnessAnalysisSummaryResponse`):
    /// {
    ///   "daily_volumes": [ { "date": "2023-10-25", "volume": 5000.0 } ],
    ///   "exercise_volumes": [
    ///     {
    ///       "exercise_id": 1,
    ///       "equipment_id": 2,
    ///       "volume": 2500.0,
    ///       "primary_muscles": ["Chest", "Triceps"]
    ///     }
    ///   ]
    /// }
    /// Calculates workout/fitness analytics for the recent date range.
    /// - Parameter daysBack: number of recent days to analyze. Default is 29.
    /// - Returns: A JSON fitness analysis summary.
    func fetchFitnessAnalysisSummary(daysBack: Int) async throws -> FitnessAnalysisSummaryResponse {
        try await customsupabase
            .rpc("get_fitness_analysis_summary", params: ["days_back": daysBack])
            .execute()
            .value
    }

    nonisolated struct FetchFitnessHomeBundleParams: Codable, Sendable {
        let p_days_back: Int
    }

    /// Loads all main fitness home screen data in one call.
    /// - Parameter daysBack: number of recent days for analysis. Default 29.
    /// - Returns: A JSON object with routine summaries, workout sessions, and fitness analysis.
    func fetchFitnessHomeBundle(daysBack: Int) async throws -> FitnessHomeBundle {
        return try await customsupabase
            .rpc("nl_get_fitness_home_bundle", params: FetchFitnessHomeBundleParams(p_days_back: daysBack))
            .execute()
            .value
    }

    nonisolated struct FetchWorkoutRoutinesSummaryParams: Codable, Sendable {}

    /// Executes the `get_workout_routines_summary` RPC.
    /// Fetches routine/template summary data for routine cards or the fitness home screen.
    /// - Returns: A JSON summary of workout routines.
    func fetchWorkoutRoutinesSummary() async throws -> [WorkoutTemplateSummary] {
        try await customsupabase
            .rpc("get_workout_routines_summary")
            .execute()
            .value
    }

    nonisolated struct FetchWorkoutLaunchHistoryParams: Codable, Sendable {
        let routine_id: Int64?
        let lookup_items: [WorkoutLaunchHistoryLookupItem]
    }

    func fetchWorkoutLaunchHistory(
        routineID: Int64?,
        lookupItems: [WorkoutLaunchHistoryLookupItem]
    ) async throws -> [WorkoutLaunchHistorySnapshot] {
        try await customsupabase
            .rpc(
                "nl_get_workout_launch_history",
                params: FetchWorkoutLaunchHistoryParams(
                    routine_id: routineID,
                    lookup_items: lookupItems
                )
            )
            .execute()
            .value
    }

    nonisolated struct FinalizeWorkoutParams: Codable, Sendable {
        let payload: FinalizeWorkoutPayload
    }

    func finalizeWorkout(_ payload: FinalizeWorkoutPayload) async throws -> FinalizeWorkoutResponse {
        try await customsupabase
            .rpc("nl_finalize_workout", params: FinalizeWorkoutParams(payload: payload))
            .execute()
            .value
    }

    nonisolated struct FetchExerciseProgressionParams: Codable, Sendable {
        let p_exercise_id: Int64
    }

    /// Combines strength sets and cardio logs for one exercise into one timeline ordered by workout date.
    /// - Parameter exerciseId: exercise ID.
    /// - Returns: A JSON array of historical workout entries for that exercise.
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult] {
        return try await customsupabase
            .rpc("nl_get_exercise_progression", params: FetchExerciseProgressionParams(p_exercise_id: exerciseId))
            .execute()
            .value
    }
}

