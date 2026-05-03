import Foundation

struct MuscleMetadata: Identifiable, Equatable, Codable {
    var id: Int64 { muscleID }
    let muscleID: Int64
    let muscleName: String
    let isPrimary: Bool
}

struct ExerciseLibraryItem: Identifiable, Equatable, Codable {
    let id: Int64
    var name: String
    var type: ExerciseType
    var equipmentID: Int64?
    var equipmentName: String
    var muscles: [MuscleMetadata] = []

    var isRepBased: Bool { type.isRepBased }
    var isDurationBased: Bool { type.isDurationBased }
}

struct ExerciseLibrarySection: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var items: [ExerciseLibraryItem]
}

struct WorkoutExerciseCardState: Identifiable, Equatable, Codable {
    let id: Int64
    var exercise: ExerciseLibraryItem
    var sets: [WorkoutSetDraft]
    
    // Metadata from RoutineExercise
    var targetSets: Int?
    var targetReps: Int?
    var restSeconds: Int?
    var targetDuration: Decimal?
    var supersetGroupID: Int?
    var historicalHint: String?

    var supersetLabel: String? {
        supersetGroupID?.supersetLabel
    }

    var columnHeaders: [String] {
        if exercise.isRepBased {
            return ["SET", "KG", "REPS"]
        } else {
            return ["SET", "MIN", "KM", "KCAL"]
        }
    }
}

struct WorkoutSetDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var dbId: Int64?
    var setNumber: Int
    var weightText: String
    var repsText: String
    var durationText: String
    var distanceText: String
    var caloriesText: String
    var isCompleted: Bool
    var superset_group_id: Int?

    init(
        id: UUID = UUID(),
        dbId: Int64? = nil,
        setNumber: Int,
        weightText: String = "",
        repsText: String = "",
        durationText: String = "",
        distanceText: String = "",
        caloriesText: String = "",
        isCompleted: Bool = false,
        superset_group_id: Int? = nil
    ) {
        self.id = id
        self.dbId = dbId
        self.setNumber = setNumber
        self.weightText = weightText
        self.repsText = repsText
        self.durationText = durationText
        self.distanceText = distanceText
        self.caloriesText = caloriesText
        self.isCompleted = isCompleted
        self.superset_group_id = superset_group_id
    }

    func weightAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) kilograms"
    }

    func repsAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) reps"
    }

    func durationAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) duration"
    }

    func distanceAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) distance"
    }

    func caloriesAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) calories"
    }
}

nonisolated struct ActiveWorkoutDraft: Codable, Equatable, Identifiable {
    let routineID: Int64
    var id: Int64 { routineID }
    var session: WorkoutSession
    var exercises: [WorkoutExerciseCardState]
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    var lastProcessedWatchSequence: Int
    var processedWatchActionIDs: Set<UUID>
    var restEndDate: Date?
    var restTotalSeconds: Int?

    init(
        routineID: Int64,
        session: WorkoutSession,
        exercises: [WorkoutExerciseCardState],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        revision: Int = 0,
        lastProcessedWatchSequence: Int = 0,
        processedWatchActionIDs: Set<UUID> = [],
        restEndDate: Date? = nil,
        restTotalSeconds: Int? = nil
    ) {
        self.routineID = routineID
        self.session = session
        self.exercises = exercises
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.lastProcessedWatchSequence = lastProcessedWatchSequence
        self.processedWatchActionIDs = processedWatchActionIDs
        self.restEndDate = restEndDate
        self.restTotalSeconds = restTotalSeconds
    }

    mutating func apply(watchAction action: WorkoutWatchAction) {
        markProcessed(action: action)
        
        switch action.payload {
        case .requestSnapshot:
            break // No-op for draft mutation
            
        case .updateSetValues(let payload):
            guard let exerciseID = Self.resolveExerciseID(payload.reference.exerciseID, routineExerciseID: payload.reference.routineExerciseID),
                  let setUUID = UUID(uuidString: payload.reference.setID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
               let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setUUID }) {
                if let kg = payload.values.kg {
                    exercises[exerciseIndex].sets[setIndex].weightText = "\(kg)"
                }
                if let reps = payload.values.reps {
                    exercises[exerciseIndex].sets[setIndex].repsText = "\(reps)"
                }
                updatedAt = Date()
            }
            
        case .toggleSetCompletion(let payload):
            guard let exerciseID = Self.resolveExerciseID(payload.reference.exerciseID, routineExerciseID: payload.reference.routineExerciseID),
                  let setUUID = UUID(uuidString: payload.reference.setID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
               let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setUUID }) {
                exercises[exerciseIndex].sets[setIndex].isCompleted = payload.isCompleted
                updatedAt = Date()
            }
            
        case .addSet(let reference):
            guard let exerciseID = Self.resolveExerciseID(reference.exerciseID, routineExerciseID: reference.routineExerciseID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) {
                let lastSet = exercises[exerciseIndex].sets.last
                let newSet = WorkoutSetDraft(
                    id: action.id, // Use action ID for the new set
                    setNumber: (lastSet?.setNumber ?? 0) + 1,
                    weightText: lastSet?.weightText ?? "",
                    repsText: lastSet?.repsText ?? "",
                    isCompleted: false
                )
                exercises[exerciseIndex].sets.append(newSet)
                updatedAt = Date()
            }
            
        case .updateExerciseCompletion(let payload):
            guard let exerciseID = Self.resolveExerciseID(payload.reference.exerciseID, routineExerciseID: payload.reference.routineExerciseID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) {
                for i in 0..<exercises[exerciseIndex].sets.count {
                    exercises[exerciseIndex].sets[i].isCompleted = payload.isCompleted
                }
                updatedAt = Date()
            }
            
        case .finishWorkout:
            break // Handled at a higher level (saving to DB and clearing draft)
            
        case .cancelRestTimer:
            restEndDate = nil
            restTotalSeconds = nil
            updatedAt = Date()
        }
    }

    mutating func markProcessed(action: WorkoutWatchAction) {
        processedWatchActionIDs.insert(action.id)
        if action.sequence > 0 {
            lastProcessedWatchSequence = action.sequence
        }
    }

    /// Resolves an exercise ID from a watch action reference.
    /// Prefers routineExerciseID for reliable matching; falls back to parsing the string.
    static func resolveExerciseID(_ stringID: String, routineExerciseID: Int64?) -> Int64? {
        if let routineExerciseID { return routineExerciseID }
        return Int64(stringID)
    }
}

struct WorkoutTemplateSummary: Identifiable, Equatable, Codable {
    let id: Int64
    var title: String
    var exerciseCount: Int
    var setCount: Int

    var countText: String {
        let exerciseLabel = exerciseCount == 1 ? "exercise" : "exercises"
        let setLabel = setCount == 1 ? "set" : "sets"
        return "\(exerciseCount) \(exerciseLabel), \(setCount) \(setLabel)"
    }
}

struct WorkoutTemplateExerciseRow: Identifiable, Equatable {
    let id: Int64
    var exerciseName: String
    var equipmentName: String
    var setCount: Int
    var orderIndex: Int

    var setText: String {
        setCount == 1 ? "1 set" : "\(setCount) sets"
    }
}

struct WorkoutTemplateExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var routineExerciseID: Int64?
    var exercise: ExerciseLibraryItem
    var orderIndex: Int
    var targetSetsText: String
    var targetRepsText: String
    var durationText: String
    var restSecondsText: String
    var supersetGroupID: Int?

    var supersetLabel: String? {
        supersetGroupID?.supersetLabel
    }

    init(
        id: UUID = UUID(),
        routineExerciseID: Int64? = nil,
        exercise: ExerciseLibraryItem,
        orderIndex: Int,
        targetSetsText: String,
        targetRepsText: String,
        durationText: String,
        restSecondsText: String,
        supersetGroupID: Int? = nil
    ) {
        self.id = id
        self.routineExerciseID = routineExerciseID
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.targetSetsText = targetSetsText
        self.targetRepsText = targetRepsText
        self.durationText = durationText
        self.restSecondsText = restSecondsText
        self.supersetGroupID = supersetGroupID
    }
}

extension Int {
    var supersetLabel: String? {
        guard self > 0 else { return nil }
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let index = (self - 1) % letters.count
        let letter = letters[letters.index(letters.startIndex, offsetBy: index)]
        return "Superset \(letter)"
    }
}

struct WorkoutSessionSummary: Identifiable, Equatable {
    let id: Int64
    let date: Date
    let title: String
    let notes: String?
}

struct WorkoutDraftSummary: Identifiable, Equatable {
    let id: Int64
    let routineID: Int64
    let sessionPointerID: String
    let title: String
    let sessionDate: Date
    let startTime: String?
    let notes: String?
    let exerciseCount: Int
    let setCount: Int
    let completedSetCount: Int
    let updatedAt: Date

    var progressText: String {
        "\(completedSetCount)/\(setCount) sets complete"
    }

    var metadataText: String {
        let exerciseLabel = exerciseCount == 1 ? "exercise" : "exercises"
        let setLabel = setCount == 1 ? "set" : "sets"
        return "\(exerciseCount) \(exerciseLabel) • \(setCount) \(setLabel)"
    }

    var subtitleText: String {
        if let startTime, !startTime.isEmpty {
            return "Started \(sessionDate.formatted(date: .abbreviated, time: .omitted)) at \(startTime)"
        }

        return "Started \(sessionDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct FitnessAnalysisSummaryResponse: Codable, Equatable {
    struct DailyVolume: Codable, Equatable {
        let date: String
        let volume: Double
    }
    struct ExerciseVolume: Codable, Equatable {
        let exercise_id: Int64
        let equipment_id: Int64?
        let volume: Double
        let primary_muscles: [String]
    }
    
    let daily_volumes: [DailyVolume]
    let exercise_volumes: [ExerciseVolume]
}

extension ActiveWorkoutDraft {
    var summary: WorkoutDraftSummary {
        let totalSets = exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.count
        }
        let completedSets = exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter(\.isCompleted).count
        }

        return WorkoutDraftSummary(
            id: routineID,
            routineID: routineID,
            sessionPointerID: watchSessionPointer.id,
            title: session.session_type,
            sessionDate: session.date,
            startTime: session.start_time,
            notes: session.notes,
            exerciseCount: exercises.count,
            setCount: totalSets,
            completedSetCount: completedSets,
            updatedAt: updatedAt
        )
    }
}

protocol WorkoutDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles]
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog
    func deleteWorkoutSession(id: Int64) async throws
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet]
    func fetchWorkoutSessions() async throws -> [WorkoutSession]
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult]
    func fetchFitnessAnalysisSummary(daysBack: Int) async throws -> FitnessAnalysisSummaryResponse
    func fetchWorkoutRoutinesSummary() async throws -> [WorkoutTemplateSummary]
    func fetchLatestExerciseHistory(exerciseIds: [Int64]) async throws -> [WorkoutSet]
    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet
    func deleteWorkoutSet(id: Int64) async throws
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog
    func deleteCardioLog(id: Int64) async throws
}

protocol WorkoutTemplateReadingDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles]
    func fetchRoutine(by id: Int64) async throws -> Routine?
    func fetchAllRoutines() async throws -> [Routine]
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise]
}

protocol FitnessTemplateDataManaging: WorkoutTemplateReadingDataManaging {
    func updateRoutine(_ routine: Routine) async throws -> Routine
}

protocol WorkoutTemplateEditingDataManaging: FitnessTemplateDataManaging {
    func createRoutine(_ request: CreateRoutineRequest) async throws -> Routine
    func deleteRoutine(id: Int64) async throws
    func addRoutineExercise(_ request: CreateRoutineExerciseRequest) async throws -> RoutineExercise
    func updateRoutineExercise(_ routineExercise: RoutineExercise) async throws -> RoutineExercise
    func deleteRoutineExercise(id: Int64) async throws
}

extension DBManager: WorkoutDataManaging {}
extension DBManager: FitnessTemplateDataManaging {}
extension DBManager: WorkoutTemplateReadingDataManaging {}
extension DBManager: WorkoutTemplateEditingDataManaging {}
