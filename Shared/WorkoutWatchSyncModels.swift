import Foundation

// Transport models shared by iPhone and watch targets.
// Keep these free of persistence, database, SwiftUI, and app-only fitness model dependencies.

public enum WatchTab: Hashable {
    case home
    case fitness
}

public enum NeuralLoopDeepLink: String, Codable {
    case aiListen = "ai/listen"
    case tasks = "tasks"
    case habits = "habits"
    case addTask = "tasks/add"
    case addNote = "notes/add"
    case calendar = "calendar"
    case fitnessHome = "fitness"
    case fitnessActiveWorkout = "fitness/workout"
}

public nonisolated enum WorkoutSetType: String, Codable, Hashable, CaseIterable, Sendable {
    case warmup
    case working
}

public nonisolated struct WorkoutRepRange: Codable, Hashable, Sendable {
    public var minimum: Int
    public var maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public nonisolated enum WorkoutSuggestionReason: String, Codable, Hashable, Sendable {
    case warmupRepeat = "Repeat the previous warm-up"
    case rangeCeilingLoadIncrease = "All working sets reached the top of the range—add load and reset reps"
    case withinRangeRepIncrease = "All working sets reached the range—add one rep"
    case belowMinimumRepeat = "A working set missed the minimum—repeat the previous result"
    case bodyweightRepIncrease = "Add one rep while staying inside the target range"
    case bodyweightRangeComplete = "Range complete—consider added load or a harder variation"
    case cardioRepeat = "Repeat the previous cardio result"
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
    public var revision: Int
    public var generatedAt: Date
    public var lastProcessedWatchSequence: Int
    public var restEndDate: Date?
    public var restTotalSeconds: Int?
    
    public init(session: WorkoutSessionPointer, title: String, startedAt: Date? = nil, elapsedSeconds: Int? = nil, exercises: [ExerciseSnapshot] = [], lastProcessedActionID: UUID? = nil, timestamp: Date = Date(), revision: Int = 0, generatedAt: Date = Date(), lastProcessedWatchSequence: Int = 0, restEndDate: Date? = nil, restTotalSeconds: Int? = nil) {
        self.session = session
        self.title = title
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
        self.exercises = exercises
        self.lastProcessedActionID = lastProcessedActionID
        self.timestamp = timestamp
        self.revision = revision
        self.generatedAt = generatedAt
        self.lastProcessedWatchSequence = lastProcessedWatchSequence
        self.restEndDate = restEndDate
        self.restTotalSeconds = restTotalSeconds
    }
}

public struct WorkoutWatchAction: Codable, Hashable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let sequence: Int
    public let payload: WorkoutWatchActionPayload

    public init(id: UUID = UUID(), timestamp: Date = Date(), sequence: Int = 0, payload: WorkoutWatchActionPayload) {
        self.id = id
        self.timestamp = timestamp
        self.sequence = sequence
        self.payload = payload
    }
}

public nonisolated struct ExerciseSnapshot: Codable, Hashable, Identifiable {
    public let id: String
    public var sourceExerciseID: Int64?
    /// The routine-exercise ID used by the iPhone draft for lookups
    /// (i.e. WorkoutExerciseCardState.id / RoutineExercise.id).
    public var routineExerciseID: Int64?
    public var name: String
    public var isDurationBased: Bool?
    public var orderIndex: Int
    public var restDurationSeconds: Int?
    public var isCompleted: Bool
    public var sets: [SetSnapshot]
    
    public init(id: String, sourceExerciseID: Int64? = nil, routineExerciseID: Int64? = nil, name: String, isDurationBased: Bool? = nil, orderIndex: Int, restDurationSeconds: Int? = nil, isCompleted: Bool = false, sets: [SetSnapshot] = []) {
        self.id = id
        self.sourceExerciseID = sourceExerciseID
        self.routineExerciseID = routineExerciseID
        self.name = name
        self.isDurationBased = isDurationBased
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
    public var setType: WorkoutSetType?
    public var previousValues: WorkoutSetValuesSnapshot?
    public var suggestedValues: WorkoutSetValuesSnapshot?
    public var suggestionReason: WorkoutSuggestionReason?
    
    public init(id: String, sourceSetID: String? = nil, setNumber: Int, values: WorkoutSetValuesSnapshot, isCompleted: Bool = false, setType: WorkoutSetType? = nil, previousValues: WorkoutSetValuesSnapshot? = nil, suggestedValues: WorkoutSetValuesSnapshot? = nil, suggestionReason: WorkoutSuggestionReason? = nil) {
        self.id = id
        self.sourceSetID = sourceSetID
        self.setNumber = setNumber
        self.values = values
        self.isCompleted = isCompleted
        self.setType = setType
        self.previousValues = previousValues
        self.suggestedValues = suggestedValues
        self.suggestionReason = suggestionReason
    }
}

public nonisolated struct WorkoutSetValuesSnapshot: Codable, Hashable {
    public var kg: Decimal?
    public var reps: Int?
    public var durationMinutes: Decimal?
    public var distanceKilometers: Decimal?
    public var calories: Decimal?
    
    public init(kg: Decimal? = nil, reps: Int? = nil, durationMinutes: Decimal? = nil, distanceKilometers: Decimal? = nil, calories: Decimal? = nil) {
        self.kg = kg
        self.reps = reps
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.calories = calories
    }
}


