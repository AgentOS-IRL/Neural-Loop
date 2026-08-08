import Foundation
import Supabase

extension DBManager {
    private var equipmentTableName: String { "equipment" }
    private var muscleTableName: String { "muscle" }
    private var exerciseTableName: String { "exercise" }
    private var exerciseMusclesTableName: String { "exercise_muscles" }

    // MARK: - Equipment

    func createEquipment(_ request: CreateEquipmentRequest) async throws -> Equipment {
        let inserted: [Equipment] = try await customsupabase
            .from(equipmentTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let equipment = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return equipment
    }

    func fetchAllEquipment() async throws -> [Equipment] {
        try await customsupabase
            .from(equipmentTableName)
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    func updateEquipment(_ equipment: Equipment) async throws -> Equipment {
        guard let id = equipment.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateEquipmentRequest(name: equipment.name)
        let updated: [Equipment] = try await customsupabase
            .from(equipmentTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let equipment = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return equipment
    }

    func deleteEquipment(id: Int64) async throws {
        try await customsupabase
            .from(equipmentTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Muscle

    func createMuscle(_ request: CreateMuscleRequest) async throws -> Muscle {
        let inserted: [Muscle] = try await customsupabase
            .from(muscleTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let muscle = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return muscle
    }

    func fetchAllMuscles() async throws -> [Muscle] {
        try await customsupabase
            .from(muscleTableName)
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    func updateMuscle(_ muscle: Muscle) async throws -> Muscle {
        guard let id = muscle.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateMuscleRequest(name: muscle.name)
        let updated: [Muscle] = try await customsupabase
            .from(muscleTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let muscle = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return muscle
    }

    func deleteMuscle(id: Int64) async throws {
        try await customsupabase
            .from(muscleTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Exercises

    func createExercise(_ request: CreateExerciseRequest) async throws -> Exercise {
        let inserted: [Exercise] = try await customsupabase
            .from(exerciseTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let exercise = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return exercise
    }

    func fetchAllExercises() async throws -> [Exercise] {
        try await customsupabase
            .from(exerciseTableName)
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] {
        try await customsupabase
            .from(exerciseTableName)
            .select("*, \(exerciseMusclesTableName)(*, \(muscleTableName)(*))")
            .order("name", ascending: true)
            .execute()
            .value
    }

    func fetchExercise(by id: Int64) async throws -> Exercise? {
        let rows: [Exercise] = try await customsupabase
            .from(exerciseTableName)
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchExercises(equipmentId: Int64) async throws -> [Exercise] {
        try await customsupabase
            .from(exerciseTableName)
            .select()
            .eq("equipment_id", value: Int(equipmentId))
            .order("name", ascending: true)
            .execute()
            .value
    }

    func updateExercise(_ exercise: Exercise) async throws -> Exercise {
        guard let id = exercise.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        let request = UpdateExerciseRequest(
            name: exercise.name,
            type: exercise.type,
            equipment_id: exercise.equipment_id,
            notes: exercise.notes
        )
        let updated: [Exercise] = try await customsupabase
            .from(exerciseTableName)
            .update(request)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        guard let exercise = updated.first else {
            throw WorkoutDatabaseError.updateReturnedNoRows
        }

        return exercise
    }

    func deleteExercise(id: Int64) async throws {
        try await customsupabase
            .from(exerciseTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Exercise Muscles

    func addExerciseMuscle(_ request: CreateExerciseMuscleRequest) async throws -> ExerciseMuscle {
        let inserted: [ExerciseMuscle] = try await customsupabase
            .from(exerciseMusclesTableName)
            .insert(request)
            .select()
            .execute()
            .value

        guard let exerciseMuscle = inserted.first else {
            throw WorkoutDatabaseError.insertReturnedNoRows
        }

        return exerciseMuscle
    }

    func fetchExerciseMuscles(exerciseId: Int64) async throws -> [ExerciseMuscle] {
        try await customsupabase
            .from(exerciseMusclesTableName)
            .select()
            .eq("exercise_id", value: Int(exerciseId))
            .order("is_primary", ascending: false)
            .execute()
            .value
    }

    func fetchPrimaryMuscles(exerciseId: Int64) async throws -> [ExerciseMuscle] {
        try await customsupabase
            .from(exerciseMusclesTableName)
            .select()
            .eq("exercise_id", value: Int(exerciseId))
            .eq("is_primary", value: true)
            .execute()
            .value
    }

    func deleteExerciseMuscle(id: Int64) async throws {
        try await customsupabase
            .from(exerciseMusclesTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

}

