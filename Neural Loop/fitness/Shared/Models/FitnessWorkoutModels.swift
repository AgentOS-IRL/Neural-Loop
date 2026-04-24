import Foundation

struct ExerciseLibraryItem: Identifiable, Equatable, Codable {
    let id: Int64
    var name: String
    var type: ExerciseType
    var equipmentID: Int64?
    var equipmentName: String

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
    var setNumber: Int
    var weightText: String
    var repsText: String
    var durationText: String
    var distanceText: String
    var caloriesText: String
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weightText: String = "",
        repsText: String = "",
        durationText: String = "",
        distanceText: String = "",
        caloriesText: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weightText = weightText
        self.repsText = repsText
        self.durationText = durationText
        self.distanceText = distanceText
        self.caloriesText = caloriesText
        self.isCompleted = isCompleted
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

struct WorkoutSessionState: Codable, Equatable {
    var session: WorkoutSession
    var exercises: [WorkoutExerciseCardState]
}

struct WorkoutTemplateSummary: Identifiable, Equatable {
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

    init(
        id: UUID = UUID(),
        routineExerciseID: Int64? = nil,
        exercise: ExerciseLibraryItem,
        orderIndex: Int,
        targetSetsText: String,
        targetRepsText: String,
        durationText: String,
        restSecondsText: String
    ) {
        self.id = id
        self.routineExerciseID = routineExerciseID
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.targetSetsText = targetSetsText
        self.targetRepsText = targetRepsText
        self.durationText = durationText
        self.restSecondsText = restSecondsText
    }
}

struct WorkoutSessionSummary: Identifiable, Equatable {
    let id: Int64
    let date: Date
    let title: String
    let notes: String?
}

protocol WorkoutDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog
    func deleteWorkoutSession(id: Int64) async throws
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet]
    func fetchWorkoutSessions() async throws -> [WorkoutSession]
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail
}

protocol WorkoutTemplateReadingDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
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

struct ActiveWorkoutSessionWrapper: Identifiable {
    let id: Int64
    let session: WorkoutSession
    let exercises: [WorkoutExerciseCardState]
    
    init(session: WorkoutSession, exercises: [WorkoutExerciseCardState]) {
        self.id = session.id ?? 0
        self.session = session
        self.exercises = exercises
    }
}

extension DBManager: WorkoutDataManaging {}
extension DBManager: FitnessTemplateDataManaging {}
extension DBManager: WorkoutTemplateReadingDataManaging {}
extension DBManager: WorkoutTemplateEditingDataManaging {}
