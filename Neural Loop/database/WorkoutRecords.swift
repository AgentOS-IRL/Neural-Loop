//
//  Workout.swift
//  Neural Loop
//
//  Created by Codex on 22/04/2026.
//

import Foundation
import Supabase

enum ExerciseType: String, Codable, Equatable, CaseIterable, Sendable {
    case repBased = "rep-based"
    case duration

    var isRepBased: Bool {
        self == .repBased
    }

    var isDurationBased: Bool {
        self == .duration
    }
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

    var isRepBased: Bool { type.isRepBased }
    var isDurationBased: Bool { type.isDurationBased }
}

struct MuscleJoinResult: Codable, Equatable {
    let is_primary: Bool
    let muscle: Muscle
}

struct ExerciseWithMuscles: Codable, Identifiable, Equatable {
    let id: Int64
    let name: String
    let type: ExerciseType
    let equipment_id: Int64?
    let notes: String?
    let exercise_muscles: [MuscleJoinResult]

    var isRepBased: Bool { type.isRepBased }
    var isDurationBased: Bool { type.isDurationBased }
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
    var target_sets: Int? = nil
    var target_reps_min: Int? = nil
    var target_reps_max: Int? = nil
    var warmup_sets: Int = 0
    var load_increment_kg: Decimal = 2.5
    var rest_seconds: Int? = nil
    var superset_group_id: Int? = nil
    var duration: Decimal? = nil
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    let id: Int64?
    var date: Date
    var start_time: String?
    var end_time: String?
    var session_type: String
    var notes: String?
    var routine_id: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case start_time
        case end_time
        case session_type
        case notes
        case routine_id
    }

    init(
        id: Int64?,
        date: Date,
        start_time: String?,
        end_time: String?,
        session_type: String,
        notes: String?,
        routine_id: Int64? = nil
    ) {
        self.id = id
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.session_type = session_type
        self.notes = notes
        self.routine_id = routine_id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        date = try WorkoutDateCoding.decodeDate(from: container, forKey: .date)
        start_time = try container.decodeIfPresent(String.self, forKey: .start_time)
        end_time = try container.decodeIfPresent(String.self, forKey: .end_time)
        session_type = try container.decode(String.self, forKey: .session_type)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        routine_id = try container.decodeIfPresent(Int64.self, forKey: .routine_id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(WorkoutDateCoding.string(from: date), forKey: .date)
        try container.encodeIfPresent(start_time, forKey: .start_time)
        try container.encodeIfPresent(end_time, forKey: .end_time)
        try container.encode(session_type, forKey: .session_type)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(routine_id, forKey: .routine_id)
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
    var routine_exercise_id: Int64? = nil
    var set_type: WorkoutSetType = .working
}

struct CardioLog: Codable, Identifiable, Equatable {
    let id: Int64?
    var workout_session_id: Int64
    var exercise_id: Int64
    var distance_meters: Decimal?
    var duration_minutes: Decimal?
    var calories: Decimal?
    var routine_exercise_id: Int64? = nil
    var set_number: Int = 1
}

struct WorkoutSessionDetail: Equatable, Codable {
    let session: WorkoutSession
    let exercises: [WorkoutSessionExerciseDetail]
}

struct WorkoutSessionExerciseDetail: Equatable, Codable {
    let exerciseId: Int64
    let exerciseName: String
    let exerciseType: ExerciseType
    let sets: [WorkoutSet]
    let cardioLogs: [CardioLog]
}

struct ExerciseProgressionResult: Codable {
    let date: Date
    let weight: Decimal?
    let reps: Int?
    let distance_meters: Decimal?
    let duration_minutes: Decimal?
    let calories: Decimal?

    enum CodingKeys: String, CodingKey {
        case weight, reps, calories
        case distance_meters = "distance_meters"
        case duration_minutes = "duration_minutes"
        case workout_session
    }

    private struct SessionWrapper: Codable {
        let date: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weight = try container.decodeIfPresent(Decimal.self, forKey: .weight)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        distance_meters = try container.decodeIfPresent(Decimal.self, forKey: .distance_meters)
        duration_minutes = try container.decodeIfPresent(Decimal.self, forKey: .duration_minutes)
        calories = try container.decodeIfPresent(Decimal.self, forKey: .calories)
        
        let session = try container.decode(SessionWrapper.self, forKey: .workout_session)
        if let decodedDate = WorkoutDateCoding.date(from: session.date) {
            self.date = decodedDate
        } else {
            throw DecodingError.dataCorruptedError(forKey: .workout_session, in: container, debugDescription: "Invalid date format: \(session.date)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(distance_meters, forKey: .distance_meters)
        try container.encodeIfPresent(duration_minutes, forKey: .duration_minutes)
        try container.encodeIfPresent(calories, forKey: .calories)
        
        let session = SessionWrapper(date: WorkoutDateCoding.string(from: date))
        try container.encode(session, forKey: .workout_session)
    }

    // Internal init for testing or manual creation
    init(date: Date, weight: Decimal? = nil, reps: Int? = nil, distance: Decimal? = nil, duration: Decimal? = nil, calories: Decimal? = nil) {
        self.date = date
        self.weight = weight
        self.reps = reps
        self.distance_meters = distance
        self.duration_minutes = duration
        self.calories = calories
    }
}


