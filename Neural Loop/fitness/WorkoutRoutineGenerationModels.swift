import Foundation

struct WorkoutRoutineGenerationExercise: Codable, Equatable, Sendable {
    var name: String
    var equipment: String

    enum CodingKeys: String, CodingKey {
        case name
        case equipment
    }
}

struct WorkoutRoutineGenerationPayload: Codable, Equatable, Sendable {
    var routineName: String
    var notes: String
    var exercises: [WorkoutRoutineGenerationExercise]

    enum CodingKeys: String, CodingKey {
        case routineName = "routine_name"
        case notes
        case exercises
    }
}

