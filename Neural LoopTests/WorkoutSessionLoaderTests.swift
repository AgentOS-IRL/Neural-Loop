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
        
        XCTAssertEqual(results[0].sets[0].weightText, WeightFormatter.format(100))
    }
    
    func testMultiplePriorSetsMaxWins() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [
            WorkoutSetDraft(setNumber: 1, weightText: "", repsText: ""),
            WorkoutSetDraft(setNumber: 2, weightText: "", repsText: "")
        ]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: 80, superset_group_id: nil),
            WorkoutSet(id: 2, workout_session_id: 1, exercise_id: exerciseId, set_number: 2, reps: 10, weight: 120.5, superset_group_id: nil),
            WorkoutSet(id: 3, workout_session_id: 2, exercise_id: exerciseId, set_number: 1, reps: 5, weight: 110, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, WeightFormatter.format(120.5))
        XCTAssertEqual(results[0].sets[1].weightText, WeightFormatter.format(120.5))
    }
    
    func testMixedNilNonNilWeights() async {
        let exerciseId: Int64 = 101
        let exercise = ExerciseLibraryItem(id: exerciseId, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        let initialSets = [WorkoutSetDraft(setNumber: 1, weightText: "", repsText: "")]
        let exerciseState = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: initialSets)
        
        db.stubHistory[exerciseId] = [
            WorkoutSet(id: 1, workout_session_id: 1, exercise_id: exerciseId, set_number: 1, reps: 10, weight: nil, superset_group_id: nil),
            WorkoutSet(id: 2, workout_session_id: 1, exercise_id: exerciseId, set_number: 2, reps: 10, weight: 50, superset_group_id: nil)
        ]
        
        let results = await loader.prefillHistoricalWeights(for: [exerciseState])
        
        XCTAssertEqual(results[0].sets[0].weightText, WeightFormatter.format(50))
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
}
