import XCTest
@testable import Neural_Loop

class ExerciseProgressionViewModelTests: XCTestCase {
    var viewModel: ExerciseProgressionViewModel!
    var mockDB: MockWorkoutDataManager!

    @MainActor
    override func setUp() {
        super.setUp()
        mockDB = MockWorkoutDataManager()
        viewModel = ExerciseProgressionViewModel(
            exerciseId: 1,
            exerciseName: "Bench Press",
            exerciseType: .repBased,
            dataManager: mockDB
        )
    }

    @MainActor
    func testOneRepMaxCalculation() {
        // weight * (36 / (37 - reps))
        // 100kg for 10 reps -> 100 * (36 / 27) = 100 * 1.333 = 133.33
        let orm = viewModel.calculateOneRepMax(weight: 100, reps: 10)
        XCTAssertEqual(orm ?? 0, 133.33, accuracy: 0.01)
        
        // 100kg for 1 rep -> 100
        let orm1 = viewModel.calculateOneRepMax(weight: 100, reps: 1)
        XCTAssertEqual(orm1, 100.0)
        
        // High reps edge case
        let ormHigh = viewModel.calculateOneRepMax(weight: 50, reps: 40)
        XCTAssertNil(ormHigh)
    }

    @MainActor
    func testVolumeCalculation() {
        let results = [
            ExerciseProgressionResult(date: Date(), weight: 100, reps: 10),
            ExerciseProgressionResult(date: Date(), weight: 110, reps: 8)
        ]
        
        let volume = viewModel.calculateValue(for: .volume, results: results)
        // (100 * 10) + (110 * 8) = 1000 + 880 = 1880
        XCTAssertEqual(volume, 1880.0)
    }

    @MainActor
    func testPaceCalculation() {
        let results = [
            ExerciseProgressionResult(date: Date(), distance: 5000, duration: 25), // 5km in 25 min -> 5 min/km
            ExerciseProgressionResult(date: Date(), distance: 5000, duration: 20)  // 5km in 20 min -> 4 min/km
        ]
        // Total distance: 10km, Total duration: 45 min -> 4.5 min/km
        let pace = viewModel.calculateValue(for: .pace, results: results)
        XCTAssertEqual(pace, 4.5)
    }

    @MainActor
    func testDataTransformation() async {
        let date1 = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let date2 = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        
        mockDB.progressionResults = [
            ExerciseProgressionResult(date: date1, weight: 100, reps: 10),
            ExerciseProgressionResult(date: date2, weight: 110, reps: 8)
        ]
        
        await viewModel.loadData()
        
        let weightPoints = viewModel.dataPoints.filter { $0.metric == .weight }
        XCTAssertEqual(weightPoints.count, 2)
        XCTAssertEqual(weightPoints[0].value, 100.0)
        XCTAssertEqual(weightPoints[1].value, 110.0)
        XCTAssertEqual(weightPoints[0].date, date1)
        XCTAssertEqual(weightPoints[1].date, date2)
    }
}

class MockWorkoutDataManager: ExerciseProgressionReading {
    var progressionResults: [ExerciseProgressionResult] = []
    
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult] {
        return progressionResults
    }

    func fetchFitnessHomeBundle(daysBack: Int) async throws -> FitnessHomeBundle { fatalError("Not implemented") }
    func fetchFitnessAnalysisSummary(daysBack: Int) async throws -> FitnessAnalysisSummaryResponse { fatalError("Not implemented") }
    func fetchWorkoutRoutinesSummary() async throws -> [WorkoutTemplateSummary] { [] }
    func fetchLatestExerciseHistory(exerciseIds: [Int64]) async throws -> [WorkoutSet] { [] }
    
    // Unimplemented but required by protocol
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] { [] }
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        WorkoutSession(id: 0, date: Date(), start_time: nil, end_time: nil, session_type: "", notes: nil)
    }
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        WorkoutSet(id: 0, workout_session_id: 0, exercise_id: 0, set_number: 0, reps: 0)
    }
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        CardioLog(id: 0, workout_session_id: 0, exercise_id: 0)
    }
    func deleteWorkoutSession(id: Int64) async throws {}
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] { [] }
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [] }
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail {
        fatalError("Not implemented")
    }
    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession { session }
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet { set }
    func deleteWorkoutSet(id: Int64) async throws {}
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog { log }
    func deleteCardioLog(id: Int64) async throws {}
}
