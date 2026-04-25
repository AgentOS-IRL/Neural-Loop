import Foundation

// Transport models shared by iPhone and watch targets.
// Keep these free of persistence, database, SwiftUI, and app-only fitness model dependencies.

struct WorkoutSessionPointer: Codable, Hashable, Identifiable {
    let id: String
    var routineID: Int64?
    var workoutSessionID: Int64?
}

struct ActiveWorkoutSnapshot: Codable, Hashable, Identifiable {
    var id: String { session.id }
    var session: WorkoutSessionPointer
    var title: String
    var startedAt: Date?
    var elapsedSeconds: Int?
    var exercises: [ExerciseSnapshot]
}

struct ExerciseSnapshot: Codable, Hashable, Identifiable {
    let id: String
    var sourceExerciseID: Int64?
    var name: String
    var orderIndex: Int
    var restDurationSeconds: Int?
    var isCompleted: Bool
    var sets: [SetSnapshot]
}

struct SetSnapshot: Codable, Hashable, Identifiable {
    let id: String
    var sourceSetID: String?
    var setNumber: Int
    var values: WorkoutSetValuesSnapshot
    var isCompleted: Bool
}

struct WorkoutSetValuesSnapshot: Codable, Hashable {
    var kg: Decimal?
    var reps: Int?
}

struct WorkoutWatchSessionAction: Codable, Hashable {
    var session: WorkoutSessionPointer
}

struct WorkoutWatchSetReference: Codable, Hashable {
    var session: WorkoutSessionPointer
    var exerciseID: String
    var setID: String
}

struct WorkoutWatchSetValuesAction: Codable, Hashable {
    var reference: WorkoutWatchSetReference
    var values: WorkoutSetValuesSnapshot
}

struct WorkoutWatchSetCompletionAction: Codable, Hashable {
    var reference: WorkoutWatchSetReference
    var isCompleted: Bool
}

enum WorkoutWatchActionPayload: Codable, Hashable {
    case requestSnapshot(WorkoutWatchSessionAction)
    case updateSetValues(WorkoutWatchSetValuesAction)
    case toggleSetCompletion(WorkoutWatchSetCompletionAction)
    case finishWorkout(WorkoutWatchSessionAction)

    private enum ActionType: String {
        case requestSnapshot
        case updateSetValues
        case toggleSetCompletion
        case finishWorkout
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case session
        case reference
        case values
        case isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)

        guard let type = ActionType(rawValue: typeString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown workout watch action type: \(typeString)"
            )
        }

        switch type {
        case .requestSnapshot:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .requestSnapshot(WorkoutWatchSessionAction(session: session))
        case .updateSetValues:
            let reference = try container.decode(WorkoutWatchSetReference.self, forKey: .reference)
            let values = try container.decode(WorkoutSetValuesSnapshot.self, forKey: .values)
            self = .updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        case .toggleSetCompletion:
            let reference = try container.decode(WorkoutWatchSetReference.self, forKey: .reference)
            let isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
            self = .toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        case .finishWorkout:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .finishWorkout(WorkoutWatchSessionAction(session: session))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .requestSnapshot(let action):
            try container.encode(ActionType.requestSnapshot.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
        case .updateSetValues(let action):
            try container.encode(ActionType.updateSetValues.rawValue, forKey: .type)
            try container.encode(action.reference, forKey: .reference)
            try container.encode(action.values, forKey: .values)
        case .toggleSetCompletion(let action):
            try container.encode(ActionType.toggleSetCompletion.rawValue, forKey: .type)
            try container.encode(action.reference, forKey: .reference)
            try container.encode(action.isCompleted, forKey: .isCompleted)
        case .finishWorkout(let action):
            try container.encode(ActionType.finishWorkout.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
        }
    }
}
