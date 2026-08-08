import Foundation

protocol WorkoutCatalogReading {
    func fetchAllEquipment() async throws -> [Equipment]
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles]
}

protocol WorkoutRoutineReading {
    func fetchRoutine(by id: Int64) async throws -> Routine?
    func fetchAllRoutines() async throws -> [Routine]
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise]
}

protocol WorkoutRoutineWriting {
    func createRoutine(_ request: CreateRoutineRequest) async throws -> Routine
    func updateRoutine(_ routine: Routine) async throws -> Routine
    func deleteRoutine(id: Int64) async throws
    func addRoutineExercise(_ request: CreateRoutineExerciseRequest) async throws -> RoutineExercise
    func updateRoutineExercise(_ routineExercise: RoutineExercise) async throws -> RoutineExercise
    func deleteRoutineExercise(id: Int64) async throws
}

protocol FitnessHomeReading {
    func fetchFitnessHomeBundle(daysBack: Int) async throws -> FitnessHomeBundle
    func deleteWorkoutSession(id: Int64) async throws
}

protocol WorkoutLaunchHistoryReading {
    func fetchWorkoutLaunchHistory(
        routineID: Int64?,
        lookupItems: [WorkoutLaunchHistoryLookupItem]
    ) async throws -> [WorkoutLaunchHistorySnapshot]
}

protocol WorkoutRecommendationReading {
    func fetchActiveWorkoutRecommendations(routineID: Int64) async throws -> WorkoutRecommendationResponse
}

protocol WorkoutFinalizationPersisting {
    func finalizeWorkout(_ payload: FinalizeWorkoutPayload) async throws -> FinalizeWorkoutResponse
}

protocol WorkoutSessionDetailManaging {
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail
    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet
    func deleteWorkoutSet(id: Int64) async throws
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog
    func deleteCardioLog(id: Int64) async throws
}

protocol ExerciseProgressionReading {
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult]
}

extension DBManager: WorkoutCatalogReading {}
extension DBManager: WorkoutRoutineReading {}
extension DBManager: WorkoutRoutineWriting {}
extension DBManager: FitnessHomeReading {}
extension DBManager: WorkoutLaunchHistoryReading {}
extension DBManager: WorkoutRecommendationReading {}
extension DBManager: WorkoutFinalizationPersisting {}
extension DBManager: WorkoutSessionDetailManaging {}
extension DBManager: ExerciseProgressionReading {}
