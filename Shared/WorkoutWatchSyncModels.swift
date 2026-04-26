import Foundation

// Transport models shared by iPhone and watch targets.
// Keep these free of persistence, database, SwiftUI, and app-only fitness model dependencies.

public enum WatchTab: Hashable {
    case home
    case fitness
}

public nonisolated struct WorkoutSessionPointer: Codable, Hashable, Identifiable {
    public let id: String
    public var routineID: Int64?
    public var workoutSessionID: Int64?
    
    public init(id: String, routineID: Int64? = nil, workoutSessionID: Int64? = nil) {
        self.id = id
        self.routineID = routineID
        self.workoutSessionID = workoutSessionID
    }
}

public nonisolated struct ActiveWorkoutSnapshot: Codable, Hashable, Identifiable {
    public var id: String { session.id }
    public var session: WorkoutSessionPointer
    public var title: String
    public var startedAt: Date?
    public var elapsedSeconds: Int?
    public var exercises: [ExerciseSnapshot]
    public var lastProcessedActionID: UUID?
    public var timestamp: Date
    
    public init(session: WorkoutSessionPointer, title: String, startedAt: Date? = nil, elapsedSeconds: Int? = nil, exercises: [ExerciseSnapshot] = [], lastProcessedActionID: UUID? = nil, timestamp: Date = Date()) {
        self.session = session
        self.title = title
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
        self.exercises = exercises
        self.lastProcessedActionID = lastProcessedActionID
        self.timestamp = timestamp
    }
}

public struct WorkoutWatchAction: Codable, Hashable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let payload: WorkoutWatchActionPayload

    public init(id: UUID = UUID(), timestamp: Date = Date(), payload: WorkoutWatchActionPayload) {
        self.id = id
        self.timestamp = timestamp
        self.payload = payload
    }
}

public nonisolated struct ExerciseSnapshot: Codable, Hashable, Identifiable {
    public let id: String
    public var sourceExerciseID: Int64?
    public var name: String
    public var orderIndex: Int
    public var restDurationSeconds: Int?
    public var isCompleted: Bool
    public var sets: [SetSnapshot]
    
    public init(id: String, sourceExerciseID: Int64? = nil, name: String, orderIndex: Int, restDurationSeconds: Int? = nil, isCompleted: Bool = false, sets: [SetSnapshot] = []) {
        self.id = id
        self.sourceExerciseID = sourceExerciseID
        self.name = name
        self.orderIndex = orderIndex
        self.restDurationSeconds = restDurationSeconds
        self.isCompleted = isCompleted
        self.sets = sets
    }

    public var completedSetsCount: Int {
        sets.filter { $0.isCompleted }.count
    }
}

public nonisolated struct SetSnapshot: Codable, Hashable, Identifiable {
    public let id: String
    public var sourceSetID: String?
    public var setNumber: Int
    public var values: WorkoutSetValuesSnapshot
    public var isCompleted: Bool
    
    public init(id: String, sourceSetID: String? = nil, setNumber: Int, values: WorkoutSetValuesSnapshot, isCompleted: Bool = false) {
        self.id = id
        self.sourceSetID = sourceSetID
        self.setNumber = setNumber
        self.values = values
        self.isCompleted = isCompleted
    }
}

public nonisolated struct WorkoutSetValuesSnapshot: Codable, Hashable {
    public var kg: Decimal?
    public var reps: Int?
    
    public init(kg: Decimal? = nil, reps: Int? = nil) {
        self.kg = kg
        self.reps = reps
    }
}

public nonisolated struct WorkoutWatchSessionAction: Codable, Hashable {
    public var session: WorkoutSessionPointer
    
    public init(session: WorkoutSessionPointer) {
        self.session = session
    }
}

public nonisolated struct WorkoutWatchSetReference: Codable, Hashable {
    public var session: WorkoutSessionPointer
    public var exerciseID: String
    public var setID: String
    
    public init(session: WorkoutSessionPointer, exerciseID: String, setID: String) {
        self.session = session
        self.exerciseID = exerciseID
        self.setID = setID
    }
}

public nonisolated struct WorkoutWatchExerciseReference: Codable, Hashable {
    public var session: WorkoutSessionPointer
    public var exerciseID: String
    
    public init(session: WorkoutSessionPointer, exerciseID: String) {
        self.session = session
        self.exerciseID = exerciseID
    }
}

public nonisolated struct WorkoutWatchSetValuesAction: Codable, Hashable {
    public var reference: WorkoutWatchSetReference
    public var values: WorkoutSetValuesSnapshot
    
    public init(reference: WorkoutWatchSetReference, values: WorkoutSetValuesSnapshot) {
        self.reference = reference
        self.values = values
    }
}

public nonisolated struct WorkoutWatchSetCompletionAction: Codable, Hashable {
    public var reference: WorkoutWatchSetReference
    public var isCompleted: Bool
    
    public init(reference: WorkoutWatchSetReference, isCompleted: Bool) {
        self.reference = reference
        self.isCompleted = isCompleted
    }
}

public nonisolated struct WorkoutWatchExerciseCompletionAction: Codable, Hashable {
    public var reference: WorkoutWatchExerciseReference
    public var isCompleted: Bool
    
    public init(reference: WorkoutWatchExerciseReference, isCompleted: Bool) {
        self.reference = reference
        self.isCompleted = isCompleted
    }
}

public nonisolated enum WorkoutWatchActionPayload: Codable, Hashable {
    case requestSnapshot(WorkoutWatchSessionAction)
    case updateSetValues(WorkoutWatchSetValuesAction)
    case toggleSetCompletion(WorkoutWatchSetCompletionAction)
    case addSet(WorkoutWatchExerciseReference)
    case updateExerciseCompletion(WorkoutWatchExerciseCompletionAction)
    case finishWorkout(WorkoutWatchSessionAction)

    private enum ActionType: String {
        case requestSnapshot
        case updateSetValues
        case toggleSetCompletion
        case addSet
        case updateExerciseCompletion
        case finishWorkout
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case session
        case reference
        case values
        case isCompleted
    }

    public init(from decoder: Decoder) throws {
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
        case .addSet:
            let reference = try container.decode(WorkoutWatchExerciseReference.self, forKey: .reference)
            self = .addSet(reference)
        case .updateExerciseCompletion:
            let reference = try container.decode(WorkoutWatchExerciseReference.self, forKey: .reference)
            let isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
            self = .updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        case .finishWorkout:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .finishWorkout(WorkoutWatchSessionAction(session: session))
        }
    }

    public func encode(to encoder: Encoder) throws {
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
        case .addSet(let reference):
            try container.encode(ActionType.addSet.rawValue, forKey: .type)
            try container.encode(reference, forKey: .reference)
        case .updateExerciseCompletion(let action):
            try container.encode(ActionType.updateExerciseCompletion.rawValue, forKey: .type)
            try container.encode(action.reference, forKey: .reference)
            try container.encode(action.isCompleted, forKey: .isCompleted)
        case .finishWorkout(let action):
            try container.encode(ActionType.finishWorkout.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
        }
    }
}

public extension WorkoutWatchActionPayload {
    var session: WorkoutSessionPointer {
        switch self {
        case .requestSnapshot(let action): return action.session
        case .updateSetValues(let action): return action.reference.session
        case .toggleSetCompletion(let action): return action.reference.session
        case .addSet(let reference): return reference.session
        case .updateExerciseCompletion(let action): return action.reference.session
        case .finishWorkout(let action): return action.session
        }
    }
}
