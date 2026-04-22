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

protocol WorkoutDataManaging {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercises() async throws -> [Exercise]
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet
    func deleteWorkoutSession(id: Int64) async throws
}

protocol FitnessTemplateDataManaging {
    func fetchAllRoutines() async throws -> [Routine]
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise]
}

extension DBManager: WorkoutDataManaging {}
extension DBManager: FitnessTemplateDataManaging {}
