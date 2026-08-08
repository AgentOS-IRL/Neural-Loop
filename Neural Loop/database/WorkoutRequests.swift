import Foundation

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
    var target_reps_min: Int?
    var target_reps_max: Int?
    var warmup_sets: Int
    var load_increment_kg: Decimal
    var rest_seconds: Int?
    var superset_group_id: Int?
    var duration: Decimal?
}

struct UpdateRoutineExerciseRequest: Codable, Equatable {
    var routine_id: Int64
    var exercise_id: Int64
    var order_index: Int
    var target_sets: Int?
    var target_reps_min: Int?
    var target_reps_max: Int?
    var warmup_sets: Int
    var load_increment_kg: Decimal
    var rest_seconds: Int?
    var superset_group_id: Int?
    var duration: Decimal?

    enum CodingKeys: String, CodingKey {
        case routine_id
        case exercise_id
        case order_index
        case target_sets
        case target_reps_min
        case target_reps_max
        case warmup_sets
        case load_increment_kg
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
        try container.encodeNullable(target_reps_min, forKey: .target_reps_min)
        try container.encodeNullable(target_reps_max, forKey: .target_reps_max)
        try container.encode(warmup_sets, forKey: .warmup_sets)
        try container.encode(load_increment_kg, forKey: .load_increment_kg)
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
    var routine_id: Int64?

    enum CodingKeys: String, CodingKey {
        case date
        case start_time
        case end_time
        case session_type
        case notes
        case routine_id
    }

    init(
        date: Date? = nil,
        start_time: String? = nil,
        end_time: String? = nil,
        session_type: String,
        notes: String? = nil,
        routine_id: Int64? = nil
    ) {
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.session_type = session_type
        self.notes = notes
        self.routine_id = routine_id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try WorkoutDateCoding.decodeDateIfPresent(from: container, forKey: .date)
        start_time = try container.decodeIfPresent(String.self, forKey: .start_time)
        end_time = try container.decodeIfPresent(String.self, forKey: .end_time)
        session_type = try container.decode(String.self, forKey: .session_type)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        routine_id = try container.decodeIfPresent(Int64.self, forKey: .routine_id)
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
        try container.encodeIfPresent(routine_id, forKey: .routine_id)
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
    var routine_exercise_id: Int64? = nil
    var set_type: WorkoutSetType = .working
}

struct UpdateWorkoutSetRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var set_number: Int
    var reps: Int
    var weight: Decimal?
    var superset_group_id: Int?
    var routine_exercise_id: Int64? = nil
    var set_type: WorkoutSetType = .working

    enum CodingKeys: String, CodingKey {
        case workout_session_id
        case exercise_id
        case set_number
        case reps
        case weight
        case superset_group_id
        case routine_exercise_id
        case set_type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workout_session_id, forKey: .workout_session_id)
        try container.encode(exercise_id, forKey: .exercise_id)
        try container.encode(set_number, forKey: .set_number)
        try container.encode(reps, forKey: .reps)
        try container.encodeNullable(weight, forKey: .weight)
        try container.encodeNullable(superset_group_id, forKey: .superset_group_id)
        try container.encodeNullable(routine_exercise_id, forKey: .routine_exercise_id)
        try container.encode(set_type, forKey: .set_type)
    }
}

struct CreateCardioLogRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var distance_meters: Decimal?
    var duration_minutes: Decimal?
    var calories: Decimal?
    var routine_exercise_id: Int64? = nil
    var set_number: Int = 1
}

struct WorkoutLaunchHistoryLookupItem: Codable, Equatable, Sendable {
    let routine_exercise_id: Int64
    let exercise_id: Int64
    let exercise_type: ExerciseType
}

struct WorkoutLaunchHistoryStrengthSet: Codable, Equatable, Sendable {
    let routine_exercise_id: Int64?
    let set_type: WorkoutSetType
    let set_number: Int
    let reps: Int
    let weight: Decimal?
}

struct WorkoutLaunchHistoryCardioLog: Codable, Equatable, Sendable {
    let routine_exercise_id: Int64?
    let set_number: Int
    let duration_minutes: Decimal?
    let distance_meters: Decimal?
    let calories: Decimal?
}

struct WorkoutLaunchHistorySnapshot: Codable, Equatable, Sendable {
    let routine_exercise_id: Int64
    let exercise_id: Int64
    let source_scope: WorkoutHistorySource.Scope?
    let source_date: String?
    let source_session_id: Int64?
    let strength_sets: [WorkoutLaunchHistoryStrengthSet]
    let cardio_logs: [WorkoutLaunchHistoryCardioLog]
}

struct FinalizeWorkoutSessionPayload: Codable, Equatable, Sendable {
    let date: String
    let start_time: String?
    let end_time: String?
    let session_type: String
    let notes: String?
}

struct FinalizeWorkoutSetPayload: Codable, Equatable, Sendable {
    let exercise_id: Int64
    let routine_exercise_id: Int64?
    let set_type: WorkoutSetType
    let set_number: Int
    let reps: Int
    let weight: Decimal?
    let superset_group_id: Int?
}

struct FinalizeWorkoutCardioPayload: Codable, Equatable, Sendable {
    let exercise_id: Int64
    let routine_exercise_id: Int64?
    let set_number: Int
    let distance_meters: Decimal?
    let duration_minutes: Decimal?
    let calories: Decimal?
}

struct FinalizeWorkoutPayload: Codable, Equatable, Sendable {
    let routine_id: Int64
    let session: FinalizeWorkoutSessionPayload
    let sets: [FinalizeWorkoutSetPayload]
    let cardio_logs: [FinalizeWorkoutCardioPayload]
}

struct FinalizeWorkoutResponse: Codable, Equatable, Sendable {
    let session_id: Int64
}

struct UpdateCardioLogRequest: Codable, Equatable {
    var workout_session_id: Int64
    var exercise_id: Int64
    var distance_meters: Decimal?
    var duration_minutes: Decimal?
    var calories: Decimal?
    var routine_exercise_id: Int64? = nil
    var set_number: Int = 1

    enum CodingKeys: String, CodingKey {
        case workout_session_id
        case exercise_id
        case distance_meters
        case duration_minutes
        case calories
        case routine_exercise_id
        case set_number
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workout_session_id, forKey: .workout_session_id)
        try container.encode(exercise_id, forKey: .exercise_id)
        try container.encodeNullable(distance_meters, forKey: .distance_meters)
        try container.encodeNullable(duration_minutes, forKey: .duration_minutes)
        try container.encodeNullable(calories, forKey: .calories)
        try container.encodeNullable(routine_exercise_id, forKey: .routine_exercise_id)
        try container.encode(set_number, forKey: .set_number)
    }
}


