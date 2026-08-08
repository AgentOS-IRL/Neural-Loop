import Foundation
import Supabase

extension DBManager {
    private var routineTableName: String { "routine" }
    private var routineExerciseTableName: String { "routine_exercise" }

    // MARK: - Routines

    func createRoutine(_ request: CreateRoutineRequest) async throws -> Routine {
        let inserted: [Routine] = try await customsupabase
            .from(routineTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let routine = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return routine
    }

    func fetchAllRoutines() async throws -> [Routine] {
        try await customsupabase
            .from(routineTableName)
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    func fetchRoutine(by id: Int64) async throws -> Routine? {
        let rows: [Routine] = try await customsupabase
            .from(routineTableName)
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func updateRoutine(_ routine: Routine) async throws -> Routine {
        guard let id = routine.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateRoutineRequest(name: routine.name, notes: routine.notes)
        let updated: [Routine] = try await customsupabase
            .from(routineTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let routine = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return routine
    }

    func deleteRoutine(id: Int64) async throws {
        try await customsupabase
            .from(routineTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Routine Exercises

    func addRoutineExercise(_ request: CreateRoutineExerciseRequest) async throws -> RoutineExercise {
        let inserted: [RoutineExercise] = try await customsupabase
            .from(routineExerciseTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let routineExercise = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return routineExercise
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        try await customsupabase
            .from(routineExerciseTableName)
            .select()
            .eq("routine_id", value: Int(routineId))
            .order("order_index", ascending: true)
            .execute()
            .value
    }

    func updateRoutineExercise(_ routineExercise: RoutineExercise) async throws -> RoutineExercise {
        guard let id = routineExercise.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateRoutineExerciseRequest(
            routine_id: routineExercise.routine_id,
            exercise_id: routineExercise.exercise_id,
            order_index: routineExercise.order_index,
            target_sets: routineExercise.target_sets,
            target_reps_min: routineExercise.target_reps_min,
            target_reps_max: routineExercise.target_reps_max,
            warmup_sets: routineExercise.warmup_sets,
            load_increment_kg: routineExercise.load_increment_kg,
            rest_seconds: routineExercise.rest_seconds,
            superset_group_id: routineExercise.superset_group_id,
            duration: routineExercise.duration
        )
        let updated: [RoutineExercise] = try await customsupabase
            .from(routineExerciseTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let routineExercise = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return routineExercise
    }

    func deleteRoutineExercise(id: Int64) async throws {
        try await customsupabase
            .from(routineExerciseTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

}

