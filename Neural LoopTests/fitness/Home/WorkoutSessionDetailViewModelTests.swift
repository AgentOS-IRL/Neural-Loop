import XCTest
@testable import Neural_Loop

@MainActor
final class WorkoutSessionDetailViewModelTests: XCTestCase {
    
    func testStartEditingPopulatesDrafts() async {
        let sessionId: Int64 = 123
        let session = WorkoutSession(id: sessionId, date: Date(), start_time: "10:00", end_time: "11:00", session_type: "Strength", notes: "Original Notes")
        let detail = WorkoutSessionDetail(
            session: session,
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 1,
                    exerciseName: "Squat",
                    exerciseType: .repBased,
                    sets: [
                        WorkoutSet(id: 10, workout_session_id: sessionId, exercise_id: 1, set_number: 1, reps: 10, weight: 100, superset_group_id: nil)
                    ],
                    cardioLogs: []
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        XCTAssertTrue(viewModel.isEditing)
        XCTAssertEqual(viewModel.draftSession?.session_type, "Strength")
        XCTAssertEqual(viewModel.draftSession?.notes, "Original Notes")
        XCTAssertEqual(viewModel.draftExercises.count, 1)
        XCTAssertEqual(viewModel.draftExercises[0].exerciseName, "Squat")
        XCTAssertEqual(viewModel.draftExercises[0].sets.count, 1)
        XCTAssertEqual(viewModel.draftExercises[0].sets[0].dbId, 10)
        XCTAssertEqual(viewModel.draftExercises[0].sets[0].weightText, "100")
        XCTAssertEqual(viewModel.draftExercises[0].sets[0].repsText, "10")
    }
    
    func testAddAndRemoveSet() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 1,
                    exerciseName: "Squat",
                    exerciseType: .repBased,
                    sets: [
                        WorkoutSet(id: 10, workout_session_id: sessionId, exercise_id: 1, set_number: 1, reps: 10, weight: 100, superset_group_id: nil)
                    ],
                    cardioLogs: []
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        // Add Set
        viewModel.addSet(to: 1)
        XCTAssertEqual(viewModel.draftExercises[0].sets.count, 2)
        XCTAssertEqual(viewModel.draftExercises[0].sets[1].setNumber, 2)
        XCTAssertNil(viewModel.draftExercises[0].sets[1].dbId)
        
        // Remove Set
        viewModel.removeSet(at: 0, from: 1)
        XCTAssertEqual(viewModel.draftExercises[0].sets.count, 1)
        XCTAssertEqual(viewModel.draftExercises[0].sets[0].setNumber, 1)
        XCTAssertNil(viewModel.draftExercises[0].sets[0].dbId) // The one remaining was the added one
    }
    
    func testSaveChanges() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 1,
                    exerciseName: "Squat",
                    exerciseType: .repBased,
                    sets: [
                        WorkoutSet(id: 10, workout_session_id: sessionId, exercise_id: 1, set_number: 1, reps: 10, weight: 100, superset_group_id: nil)
                    ],
                    cardioLogs: []
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        viewModel.draftSession?.session_type = "Updated Title"
        viewModel.draftExercises[0].sets[0].weightText = "110"
        
        await viewModel.saveChanges()
        
        XCTAssertFalse(viewModel.isEditing)
        XCTAssertTrue(dataManager.updateWorkoutSessionCalled)
        XCTAssertTrue(dataManager.updateWorkoutSetCalled)
        XCTAssertEqual(dataManager.lastUpdatedSession?.session_type, "Updated Title")
        XCTAssertEqual(dataManager.lastUpdatedSet?.weight, 110)
    }

    func testCancelEditing() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: []
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        viewModel.draftSession?.session_type = "Changed"
        viewModel.cancelEditing()
        
        XCTAssertFalse(viewModel.isEditing)
        XCTAssertNil(viewModel.draftSession)
        XCTAssertTrue(viewModel.draftExercises.isEmpty)
    }
}

private final class FakeWorkoutSessionDetailDataManager: WorkoutDataManaging {
    var detail: WorkoutSessionDetail
    
    var updateWorkoutSessionCalled = false
    var lastUpdatedSession: WorkoutSession?
    
    var updateWorkoutSetCalled = false
    var lastUpdatedSet: WorkoutSet?
    
    var createWorkoutSetCalled = false
    var deleteWorkoutSetCalled = false
    
    init(detail: WorkoutSessionDetail) {
        self.detail = detail
    }
    
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail {
        return detail
    }
    
    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession {
        updateWorkoutSessionCalled = true
        lastUpdatedSession = session
        return session
    }
    
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet {
        updateWorkoutSetCalled = true
        lastUpdatedSet = set
        return set
    }
    
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        createWorkoutSetCalled = true
        return WorkoutSet(id: 999, workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, set_number: request.set_number, reps: request.reps, weight: request.weight, superset_group_id: request.superset_group_id)
    }
    
    func deleteWorkoutSet(id: Int64) async throws {
        deleteWorkoutSetCalled = true
    }

    // Required by protocol but not used in these tests
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] { [] }
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession { detail.session }
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
         CardioLog(id: 1, workout_session_id: 1, exercise_id: 1, distance_meters: nil, duration_minutes: nil, calories: nil)
    }
    func deleteWorkoutSession(id: Int64) async throws {}
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] { [] }
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [detail.session] }
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult] { [] }
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog { log }
    func deleteCardioLog(id: Int64) async throws {}
}
