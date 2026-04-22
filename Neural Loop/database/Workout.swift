//
//  Workout.swift
//  Neural Loop
//
//  Created by Codex on 22/04/2026.
//

import Foundation
import Supabase

enum ExerciseType: String, Codable, Equatable, CaseIterable {
    case repBased = "rep-based"
    case duration
}

struct Equipment: Codable, Identifiable, Equatable {
    let id: Int64?
    var name: String
}

struct Muscle: Codable, Identifiable, Equatable {
    let id: Int64?
    var name: String
}

struct Routine: Codable, Identifiable, Equatable {
    let id: Int64?
    var name: String
    var notes: String?
}

struct Exercise: Codable, Identifiable, Equatable {
    let id: Int64?
    var name: String
    var type: ExerciseType
    var equipment_id: Int64?
    var notes: String?
}

struct ExerciseMuscle: Codable, Identifiable, Equatable {
    let id: Int64?
    var exercise_id: Int64
    var muscle_id: Int64
    var is_primary: Bool
}

struct RoutineExercise: Codable, Identifiable, Equatable {
    let id: Int64?
    var routine_id: Int64
    var exercise_id: Int64
    var order_index: Int
    var target_sets: Int?
    var target_reps: Int?
    var rest_seconds: Int?
    var superset_group_id: Int?
    var duration: Decimal?
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    let id: Int64?
    var date: Date
    var start_time: String?
    var end_time: String?
    var session_type: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case start_time
        case end_time
        case session_type
        case notes
    }

    init(
        id: Int64?,
        date: Date,
        start_time: String?,
        end_time: String?,
        session_type: String,
        notes: String?
    ) {
        self.id = id
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.session_type = session_type
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        date = try WorkoutDateCoding.decodeDate(from: container, forKey: .date)
        start_time = try container.decodeIfPresent(String.self, forKey: .start_time)
        end_time = try container.decodeIfPresent(String.self, forKey: .end_time)
        session_type = try container.decode(String.self, forKey: .session_type)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(WorkoutDateCoding.string(from: date), forKey: .date)
        try container.encodeIfPresent(start_time, forKey: .start_time)
        try container.encodeIfPresent(end_time, forKey: .end_time)
        try container.encode(session_type, forKey: .session_type)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: Int64?
    var workout_session_id: Int64
    var exercise_id: Int64
    var set_number: Int
    var reps: Int
    var weight: Decimal?
    var superset_group_id: Int?
}

struct CardioLog: Codable, Identifiable, Equatable {
    let id: Int64?
    var workout_session_id: Int64
    var exercise_id: Int64
    var distance_meters: Decimal?
    var duration_minutes: Decimal?
    var calories: Decimal?
}

struct CreateEquipmentRequest: Codable, Equatable {
    var name: String
}

struct UpdateEquipmentRequest: Codable, Equatable {
    var name: String
}

struct CreateMuscleRequest: Codable, Equatable {
    var name: String
}

struct UpdateMuscleRequest: Codable, Equatable {
    var name: String
}

struct CreateRoutineRequest: Codable, Equatable {
    var name: String
    var notes: String?
}

struct UpdateRoutineRequest: Codable, Equatable {
    var name: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case name
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeNullable(notes, forKey: .notes)
    }
}

struct CreateExerciseRequest: Codable, Equatable {
    var name: String
    var type: ExerciseType
    var equipment_id: Int64?
    var notes: String?
}

struct UpdateExerciseRequest: Codable, Equatable {
    var name: String
    var type: ExerciseType
    var equipment_id: Int64?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case equipment_id
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeNullable(equipment_id, forKey: .equipment_id)
        try container.encodeNullable(notes, forKey: .notes)
    }
}

struct CreateExerciseMuscleRequest: Codable, Equatable {
    var exercise_id: Int64
    var muscle_id: Int64
    var is_primary: Bool
}

struct CreateRoutineExerciseRequest: Codable, Equatable {
    var routine_id: Int64
    var exercise_id: Int64
    var order_index: Int
    var target_sets: Int?
    var target_reps: Int?
    var rest_seconds: Int?
    var superset_group_id: Int?
    var duration: Decimal?
}

struct UpdateRoutineExerciseRequest: Codable, Equatable {
    var routine_id: Int64
    var exercise_id: Int64
    var order_index: Int
    var target_sets: Int?
    var target_reps: Int?
    var rest_seconds: Int?
    var superset_group_id: Int?
    var duration: Decimal?

    enum CodingKeys: String, CodingKey {
        case routine_id
        case exercise_id
        case order_index
        case target_sets
        case target_reps
        case rest_seconds
        case superset_group_id
        case duration
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(routine_id, forKey: .routine_id)
        try container.encode(exercise_id, forKey: .exercise_id)
        try container.encode(order_index, forKey: .order_index)
        try container.encodeNullable(target_sets, forKey: .target_sets)
        try container.encodeNullable(target_reps, forKey: .target_reps)
        try container.encodeNullable(rest_seconds, forKey: .rest_seconds)
        try container.encodeNullable(superset_group_id, forKey: .superset_group_id)
        try container.encodeNullable(duration, forKey: .duration)
    }
}

struct CreateWorkoutSessionRequest: Codable, Equatable {
    var date: Date?
    var start_time: String?
    var end_time: String?
    var session_type: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case date
        case start_time
        case end_time
        case session_type
        case notes
    }

    init(
        date: Date? = nil,
        start_time: String? = nil,
        end_time: String? = nil,
        session_type: String,
        notes: String? = nil
    ) {
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.session_type = session_type
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try WorkoutDateCoding.decodeDateIfPresent(from: container, forKey: .date)
        start_time = try container.decodeIfPresent(String.self, forKey: .start_time)
        end_time = try container.decodeIfPresent(String.self, forKey: .end_time)
        session_type = try container.decode(String.self, forKey: .session_type)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let date {
            try container.encode(WorkoutDateCoding.string(from: date), forKey: .date)
        }
        try container.encodeIfPresent(start_time, forKey: .start_time)
        try container.encodeIfPresent(end_time, forKey: .end_time)
        try container.encode(session_type, forKey: .session_type)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

struct UpdateWorkoutSessionRequest: Codable, Equatable {
    var date: Date
    var start_time: String?
    var end_time: String?
    var session_type: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case date
        case start_time
        case end_time
        case session_type
        case notes
    }

    init(
        date: Date,
        start_time: String?,
        end_time: String?,
        session_type: String,
        notes: String?
    ) {
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.session_type = session_type
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try WorkoutDateCoding.decodeDate(from: container, forKey: .date)
        start_time = try container.decodeIfPresent(String.self, forKey: .start_time)
        end_time = try container.decodeIfPresent(String.self, forKey: .end_time)
        session_type = try container.decode(String.self, forKey: .session_type)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(WorkoutDateCoding.string(from: date), forKey: .date)
        try container.encodeNullable(start_time, forKey: .start_time)
        try container.encodeNullable(end_time, forKey: .end_time)
        try container.encode(session_type, forKey: .session_type)
        try container.encodeNullable(notes, forKey: .notes)
    }
}

struct CreateWorkoutSetRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var set_number: Int
    var reps: Int
    var weight: Decimal?
    var superset_group_id: Int?
}

struct UpdateWorkoutSetRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var set_number: Int
    var reps: Int
    var weight: Decimal?
    var superset_group_id: Int?

    enum CodingKeys: String, CodingKey {
        case workout_session_id
        case exercise_id
        case set_number
        case reps
        case weight
        case superset_group_id
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workout_session_id, forKey: .workout_session_id)
        try container.encode(exercise_id, forKey: .exercise_id)
        try container.encode(set_number, forKey: .set_number)
        try container.encode(reps, forKey: .reps)
        try container.encodeNullable(weight, forKey: .weight)
        try container.encodeNullable(superset_group_id, forKey: .superset_group_id)
    }
}

struct CreateCardioLogRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var distance_meters: Decimal?
    var duration_minutes: Decimal?
    var calories: Decimal?
}

struct UpdateCardioLogRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var distance_meters: Decimal?
    var duration_minutes: Decimal?
    var calories: Decimal?

    enum CodingKeys: String, CodingKey {
        case workout_session_id
        case exercise_id
        case distance_meters
        case duration_minutes
        case calories
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workout_session_id, forKey: .workout_session_id)
        try container.encode(exercise_id, forKey: .exercise_id)
        try container.encodeNullable(distance_meters, forKey: .distance_meters)
        try container.encodeNullable(duration_minutes, forKey: .duration_minutes)
        try container.encodeNullable(calories, forKey: .calories)
    }
}

enum WorkoutDatabaseError: LocalizedError, Equatable {
    case insertReturnedNoRows
    case updateReturnedNoRows
    case missingIdentifier

    var errorDescription: String? {
        switch self {
        case .insertReturnedNoRows:
            return "Workout record could not be saved."
        case .updateReturnedNoRows:
            return "Workout record could not be updated."
        case .missingIdentifier:
            return "Workout record is missing its database identifier."
        }
    }
}

private enum WorkoutDateCoding {
    private static func makeDateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func string(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return makeDateOnlyFormatter().string(from: date)
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func decodeDate<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date {
        let value = try container.decode(String.self, forKey: key)
        if let date = makeDateOnlyFormatter().date(from: value) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected a yyyy-MM-dd or ISO-8601 date string."
        )
    }

    static func decodeDateIfPresent<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date? {
        guard try container.contains(key), !(try container.decodeNil(forKey: key)) else {
            return nil
        }

        return try decodeDate(from: container, forKey: key)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

extension DBManager {
    private var equipmentTableName: String { "equipment" }
    private var muscleTableName: String { "muscle" }
    private var routineTableName: String { "routine" }
    private var exerciseTableName: String { "exercise" }
    private var exerciseMusclesTableName: String { "exercise_muscles" }
    private var routineExerciseTableName: String { "routine_exercise" }
    private var workoutSessionTableName: String { "workout_session" }
    private var workoutSetTableName: String { "workout_set" }
    private var cardioLogTableName: String { "cardio_log" }

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
            target_reps: routineExercise.target_reps,
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
            superset_group_id: set.superset_group_id
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
            calories: log.calories
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
}
