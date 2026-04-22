import Foundation

struct ExerciseLibraryItem: Identifiable, Equatable {
    let id: Int64
    var name: String
    var type: ExerciseType
    var equipmentID: Int64?
    var equipmentName: String
}

struct ExerciseLibrarySection: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var items: [ExerciseLibraryItem]
}

struct WorkoutExerciseCardState: Identifiable, Equatable {
    let id: Int64
    var exercise: ExerciseLibraryItem
    var sets: [WorkoutSetDraft]
}

struct WorkoutSetDraft: Identifiable, Equatable {
    let id: UUID
    var setNumber: Int
    var weightText: String
    var repsText: String

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weightText: String = "",
        repsText: String = ""
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weightText = weightText
        self.repsText = repsText
    }
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

    init(
        id: UUID = UUID(),
        routineExerciseID: Int64? = nil,
        exercise: ExerciseLibraryItem,
        orderIndex: Int,
        targetSetsText: String,
        targetRepsText: String,
        durationText: String
    ) {
        self.id = id
        self.routineExerciseID = routineExerciseID
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.targetSetsText = targetSetsText
        self.targetRepsText = targetRepsText
        self.durationText = durationText
    }
}

protocol WorkoutDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet
    func deleteWorkoutSession(id: Int64) async throws
}

protocol FitnessTemplateDataManaging {
    func fetchRoutine(by id: Int64) async throws -> Routine?
    func fetchAllRoutines() async throws -> [Routine]
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise]
    func updateRoutine(_ routine: Routine) async throws -> Routine
}

protocol WorkoutTemplateReadingDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
    func fetchRoutine(by id: Int64) async throws -> Routine?
    func fetchAllRoutines() async throws -> [Routine]
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise]
}

protocol WorkoutTemplateEditingDataManaging: WorkoutTemplateReadingDataManaging {
    func createRoutine(_ request: CreateRoutineRequest) async throws -> Routine
    func updateRoutine(_ routine: Routine) async throws -> Routine
    func deleteRoutine(id: Int64) async throws
    func addRoutineExercise(_ request: CreateRoutineExerciseRequest) async throws -> RoutineExercise
    func updateRoutineExercise(_ routineExercise: RoutineExercise) async throws -> RoutineExercise
    func deleteRoutineExercise(id: Int64) async throws
}

extension DBManager: WorkoutDataManaging {}
extension DBManager: FitnessTemplateDataManaging {}
extension DBManager: WorkoutTemplateReadingDataManaging {}
extension DBManager: WorkoutTemplateEditingDataManaging {}
