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
    public var orderIndex: Int
    public var restDurationSeconds: Int?
    public var isCompleted: Bool
    public var sets: [SetSnapshot]
    
    public init(id: String, sourceExerciseID: Int64? = nil, routineExerciseID: Int64? = nil, name: String, orderIndex: Int, restDurationSeconds: Int? = nil, isCompleted: Bool = false, sets: [SetSnapshot] = []) {
        self.id = id
        self.sourceExerciseID = sourceExerciseID
        self.routineExerciseID = routineExerciseID
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
    /// The numeric routine-exercise ID that the iPhone draft uses for lookups
    /// (i.e. WorkoutExerciseCardState.id / RoutineExercise.id).
    public var routineExerciseID: Int64?
    public var setID: String
    
    public init(session: WorkoutSessionPointer, exerciseID: String, routineExerciseID: Int64? = nil, setID: String) {
        self.session = session
        self.exerciseID = exerciseID
        self.routineExerciseID = routineExerciseID
        self.setID = setID
    }
}

public nonisolated struct WorkoutWatchExerciseReference: Codable, Hashable {
    public var session: WorkoutSessionPointer
    public var exerciseID: String
    /// The numeric routine-exercise ID that the iPhone draft uses for lookups
    /// (i.e. WorkoutExerciseCardState.id / RoutineExercise.id).
    public var routineExerciseID: Int64?
    
    public init(session: WorkoutSessionPointer, exerciseID: String, routineExerciseID: Int64? = nil) {
        self.session = session
        self.exerciseID = exerciseID
        self.routineExerciseID = routineExerciseID
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
    case cancelRestTimer(WorkoutWatchSessionAction)

    private enum ActionType: String {
        case requestSnapshot
        case updateSetValues
        case toggleSetCompletion
        case addSet
        case updateExerciseCompletion
        case finishWorkout
        case cancelRestTimer
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
        case .cancelRestTimer:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .cancelRestTimer(WorkoutWatchSessionAction(session: session))
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
        case .cancelRestTimer(let action):
            try container.encode(ActionType.cancelRestTimer.rawValue, forKey: .type)
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
        case .cancelRestTimer(let action): return action.session
        }
    }
}

// MARK: - Acknowledgement & Finalization Models

public struct WorkoutActionAck: Codable {
    public let actionID: UUID
    public let status: AckStatus
    
    public enum AckStatus: String, Codable {
        case applied
        case failed
        case notFound
    }
    
    public init(actionID: UUID, status: AckStatus) {
        self.actionID = actionID
        self.status = status
    }
}

public struct WorkoutFinalizedResult: Codable {
    public let sessionID: String
    public let success: Bool
    public let errorMessage: String?
    
    public init(sessionID: String, success: Bool, errorMessage: String? = nil) {
        self.sessionID = sessionID
        self.success = success
        self.errorMessage = errorMessage
    }
}

public enum WorkoutSyncPayload: Codable {
    case active(ActiveWorkoutSnapshot)
    case cleared(ClearedWorkoutSnapshot)
}

public struct ClearedWorkoutSnapshot: Codable {
    public let sessionID: String
    public let reason: ClearReason
    public let clearedAt: Date
    
    public init(sessionID: String, reason: ClearReason, clearedAt: Date = Date()) {
        self.sessionID = sessionID
        self.reason = reason
        self.clearedAt = clearedAt
    }
}

public enum ClearReason: String, Codable {
    case finalized
    case cancelledOnPhone
    case staleExpired
    case replacedByNewSession
}

// MARK: - Workout Display State (Live Activity & Complication)

/// Lightweight display-only model for Live Activities and Watch Complications.
/// Represents "what should be shown externally" without internal draft details.
public enum WorkoutDisplayMode: String, Codable, Hashable {
    case repEntry
    case resting
    case finished
}

public struct WorkoutDisplayState: Codable, Hashable {
    public var sessionID: String
    public var workoutTitle: String
    public var currentExerciseName: String
    public var currentSetNumber: Int
    public var totalSets: Int
    public var targetReps: Int?
    public var completedReps: Int?
    public var weightKg: Decimal?
    public var restEndDate: Date?
    public var restTotalSeconds: Int?
    public var mode: WorkoutDisplayMode
    public var exerciseProgress: Double  // 0.0–1.0 across all exercises
    public var updatedAt: Date

    public init(
        sessionID: String,
        workoutTitle: String,
        currentExerciseName: String = "",
        currentSetNumber: Int = 1,
        totalSets: Int = 1,
        targetReps: Int? = nil,
        completedReps: Int? = nil,
        weightKg: Decimal? = nil,
        restEndDate: Date? = nil,
        restTotalSeconds: Int? = nil,
        mode: WorkoutDisplayMode = .repEntry,
        exerciseProgress: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.workoutTitle = workoutTitle
        self.currentExerciseName = currentExerciseName
        self.currentSetNumber = currentSetNumber
        self.totalSets = totalSets
        self.targetReps = targetReps
        self.completedReps = completedReps
        self.weightKg = weightKg
        self.restEndDate = restEndDate
        self.restTotalSeconds = restTotalSeconds
        self.mode = mode
        self.exerciseProgress = exerciseProgress
        self.updatedAt = updatedAt
    }
}

public extension WorkoutDisplayState {
    /// UserDefaults key used by both iOS widget extension and watchOS complication.
    static let userDefaultsKey = "com.neuralloop.workoutDisplayState"
    /// App Group suite name shared between app, widget extension, and watch.
    static let appGroupSuite = "group.com.sanjeevhalyal.Neural-Loop"
}

// MARK: - WorkoutDisplayState Mapper

public extension ActiveWorkoutSnapshot {
    func displayState(restEndDate: Date? = nil, restTotalSeconds: Int? = nil) -> WorkoutDisplayState {
        let actualRestEnd = restEndDate ?? self.restEndDate
        let actualRestTotal = restTotalSeconds ?? self.restTotalSeconds

        let totalExercises = exercises.count
        let completedExercises = exercises.filter { $0.isCompleted }.count
        let progress: Double = totalExercises > 0 ? Double(completedExercises) / Double(totalExercises) : 0

        // Find the first incomplete exercise, or fall back to the last one
        let currentExercise = exercises.first(where: { !$0.isCompleted }) ?? exercises.last

        // Find the first incomplete set within that exercise
        let currentSet = currentExercise?.sets.first(where: { !$0.isCompleted })
            ?? currentExercise?.sets.last

        let mode: WorkoutDisplayMode
        if actualRestEnd != nil {
            mode = .resting
        } else if exercises.allSatisfy({ $0.isCompleted }) && !exercises.isEmpty {
            mode = .finished
        } else {
            mode = .repEntry
        }

        return WorkoutDisplayState(
            sessionID: session.id,
            workoutTitle: title,
            currentExerciseName: currentExercise?.name ?? "",
            currentSetNumber: currentSet?.setNumber ?? 1,
            totalSets: currentExercise?.sets.count ?? 1,
            targetReps: currentSet?.values.reps,
            completedReps: currentSet?.values.reps,
            weightKg: currentSet?.values.kg,
            restEndDate: actualRestEnd,
            restTotalSeconds: actualRestTotal,
            mode: mode,
            exerciseProgress: progress,
            updatedAt: Date()
        )
    }
}

// MARK: - Live Activity Attributes (ActivityKit)

#if canImport(ActivityKit)
import ActivityKit

public struct WorkoutActivityAttributes: ActivityAttributes {
    /// Dynamic content that updates during the activity's lifetime.
    public struct ContentState: Codable, Hashable {
        public var exerciseName: String
        public var setNumber: Int
        public var totalSets: Int
        public var targetReps: Int?
        public var completedReps: Int?
        public var weightKg: Decimal?
        public var restEndDate: Date?
        public var restTotalSeconds: Int?
        public var progress: Double          // 0.0–1.0 overall exercise progress
        public var mode: WorkoutDisplayMode  // repEntry, resting, finished

        public init(
            exerciseName: String,
            setNumber: Int,
            totalSets: Int,
            targetReps: Int? = nil,
            completedReps: Int? = nil,
            weightKg: Decimal? = nil,
            restEndDate: Date? = nil,
            restTotalSeconds: Int? = nil,
            progress: Double = 0,
            mode: WorkoutDisplayMode = .repEntry
        ) {
            self.exerciseName = exerciseName
            self.setNumber = setNumber
            self.totalSets = totalSets
            self.targetReps = targetReps
            self.completedReps = completedReps
            self.weightKg = weightKg
            self.restEndDate = restEndDate
            self.restTotalSeconds = restTotalSeconds
            self.progress = progress
            self.mode = mode
        }
    }

    /// Static context that does not change during the activity's lifetime.
    public var sessionID: String
    public var workoutTitle: String

    public init(sessionID: String, workoutTitle: String) {
        self.sessionID = sessionID
        self.workoutTitle = workoutTitle
    }
}
#endif
