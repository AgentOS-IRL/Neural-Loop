import XCTest
@testable import Neural_Loop

final class WorkoutSessionLoaderTests: XCTestCase {
    
    private var db: MockWorkoutSessionLoaderDataManager!
    private var loader: WorkoutSessionLoader!
    
    override func setUp() {
        super.setUp()
        db = MockWorkoutSessionLoaderDataManager()
        loader = WorkoutSessionLoader(db: db)
    }
    
    func testNoPriorSets() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [WorkoutSetDraft(setNumber: 1, weightText: "", repsText: "")]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        db.stubHistory[exerciseId] = []
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, "")
    }
    
    func testOnePriorSet() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [WorkoutSetDraft(setNumber: 1, weightText: "", repsText: "")]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: 100, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, NumericFormatter.format(100))
    }
    
    func testMultiplePriorSetsRecentWins() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [
            WorkoutSetDraft(setNumber: 1, weightText: "", repsText: ""),
            WorkoutSetDraft(setNumber: 2, weightText: "", repsText: "")
        ]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        // Session 1: 120.5kg x 10 (Highest weight)
        // Session 2 (Latest): 110kg x 5 (Latest session, but lower weight)
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: 80, superset_group_id: nil),
            WorkoutSet(id: 2, workout_session_id: 1, exercise_id: exerciseId, set_number: 2, reps: 10, weight: 120.5, superset_group_id: nil),
            WorkoutSet(id: 3, workout_session_id: 2, exercise_id: exerciseId, set_number: 1, reps: 5, weight: 110, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        // Should use Session 2's set 1 for both current sets (due to fallback for the second set)
        XCTAssertEqual(results[0].sets[0].weightText, NumericFormatter.format(110))
        XCTAssertEqual(results[0].sets[0].repsText, "5")
        XCTAssertEqual(results[0].sets[1].weightText, NumericFormatter.format(110))
        XCTAssertEqual(results[0].sets[1].repsText, "5")
        
        XCTAssertEqual(results[0].historicalHint, "Last: \(NumericFormatter.format(110))kg x 5")
    }
    
    func testFallbackToLastSet() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [
            WorkoutSetDraft(setNumber: 1, weightText: "", repsText: ""),
            WorkoutSetDraft(setNumber: 2, weightText: "", repsText: ""),
            WorkoutSetDraft(setNumber: 3, weightText: "", repsText: "")
        ]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: 100, superset_group_id: nil),
            WorkoutSet(id: 2, workout_session_id: 1, exercise_id: exerciseId, set_number: 2, reps: 8, weight: 110, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, NumericFormatter.format(100))
        XCTAssertEqual(results[0].sets[1].weightText, NumericFormatter.format(110))
        XCTAssertEqual(results[0].sets[2].weightText, NumericFormatter.format(110), "Should fallback to last set of history")
    }

    func testHistoricalHintPicksBestSetOfLatestSession() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [])
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: 100, superset_group_id: nil),
            WorkoutSet(id: 2, workout_session_id: 1, exercise_id: exerciseId, set_number: 2, reps: 2, weight: 200, superset_group_id: nil) // 400 volume
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        // 100 * 10 = 1000 volume, so 100kg x 10 is better than 200kg x 2
        XCTAssertEqual(results[0].historicalHint, "Last: \(NumericFormatter.format(100))kg x 10")
    }

    func testHistoricalHintForBodyweightExercise() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Pushup", type: .repBased, equipmentID: nil, equipmentName: "None")
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [])
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 20, weight: nil, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].historicalHint, "Last: 20 reps")
    }
    
    func testMixedNilNonNilWeights() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [
            WorkoutSetDraft(setNumber: 1, weightText: "", repsText: ""),
            WorkoutSetDraft(setNumber: 2, weightText: "", repsText: "")
        ]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: nil, superset_group_id: nil),
            WorkoutSet(id: 2, workout_session_id: 1, exercise_id: exerciseId, set_number: 2, reps: 12, weight: 50, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, "")
        XCTAssertEqual(results[0].sets[0].repsText, "10")
        XCTAssertEqual(results[0].sets[1].weightText, NumericFormatter.format(50))
        XCTAssertEqual(results[0].sets[1].repsText, "12")
    }
    
    func testCardioUntouched() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Run", type: .duration, equipmentID: nil, equipmentName: "Treadmill")
        let initialSets = [WorkoutSetDraft(setNumber: 1, weightText: "", repsText: "")]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        // Even if there's history (unlikely for duration via WorkoutSet, but just in case)
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 0, weight: 100, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, "")
    }
}

class MockWorkoutSessionLoaderDataManager: WorkoutDataManaging {
    var stubHistory: [Int64: [WorkoutSet]] = [:]
    
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] {
        stubHistory[exerciseId] ?? []
    }
    
    // Unused by WorkoutSessionLoader
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] { [] }
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        fatalError("Not used")
    }
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        fatalError("Not used")
    }
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        fatalError("Not used")
    }
    func deleteWorkoutSession(id: Int64) async throws {}
    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        []
    }

    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail {
        throw WorkoutDatabaseError.missingIdentifier
    }

    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult] {
        return []
    }

    func fetchFitnessHomeBundle(daysBack: Int) async throws -> FitnessHomeBundle { fatalError("Not implemented") }
    func fetchFitnessAnalysisSummary(daysBack: Int) async throws -> FitnessAnalysisSummaryResponse { fatalError("Not implemented") }
    func fetchWorkoutRoutinesSummary() async throws -> [WorkoutTemplateSummary] { [] }
    func fetchLatestExerciseHistory(exerciseIds: [Int64]) async throws -> [WorkoutSet] { [] }

    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession { session }
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet { set }
    func deleteWorkoutSet(id: Int64) async throws {}
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog { log }
    func deleteCardioLog(id: Int64) async throws {}
}
