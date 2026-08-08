import Foundation

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
            targetReps: currentSet?.suggestedValues?.reps ?? currentSet?.values.reps,
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

