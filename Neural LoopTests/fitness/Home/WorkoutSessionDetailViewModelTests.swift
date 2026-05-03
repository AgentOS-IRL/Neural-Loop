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

    func testSaveChangesSanitizesTimes() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: "10:00", end_time: "11:00", session_type: "Test", notes: nil),
            exercises: []
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        viewModel.draftSession?.start_time = ""
        viewModel.draftSession?.end_time = "   "
        
        await viewModel.saveChanges()
        
        XCTAssertNil(dataManager.lastUpdatedSession?.start_time)
        XCTAssertNil(dataManager.lastUpdatedSession?.end_time)
    }

    func testSaveChangesNormalizesTimes() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: []
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        // WorkoutTimeCoding.normalize converts ISO8601 to HH:mm:ss
        viewModel.draftSession?.start_time = "2026-04-25T10:00:00Z"
        
        await viewModel.saveChanges()
        
        XCTAssertNotNil(dataManager.lastUpdatedSession?.start_time)
        XCTAssertTrue(dataManager.lastUpdatedSession!.start_time!.contains(":"))
    }

    func testSaveChangesWithDeletions() async {
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
        
        // Remove the only set
        viewModel.removeSet(at: 0, from: 1)
        
        await viewModel.saveChanges()
        
        XCTAssertTrue(dataManager.deleteWorkoutSetCalled)
        XCTAssertEqual(dataManager.deletedSetIds.count, 1)
        XCTAssertEqual(dataManager.deletedSetIds[0], 10)
    }

    func testSaveChangesWithNewSet() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 1,
                    exerciseName: "Squat",
                    exerciseType: .repBased,
                    sets: [],
                    cardioLogs: []
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        // Add a new set
        viewModel.addSet(to: 1)
        viewModel.draftExercises[0].sets[0].weightText = "100"
        viewModel.draftExercises[0].sets[0].repsText = "10"
        
        await viewModel.saveChanges()
        
        XCTAssertTrue(dataManager.createWorkoutSetCalled)
        XCTAssertEqual(dataManager.lastCreatedSetRequest?.weight, 100)
        XCTAssertEqual(dataManager.lastCreatedSetRequest?.reps, 10)
    }

    func testSaveChangesWithCardioLogUpdate() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 2,
                    exerciseName: "Running",
                    exerciseType: .duration,
                    sets: [],
                    cardioLogs: [
                        CardioLog(id: 50, workout_session_id: sessionId, exercise_id: 2, distance_meters: 1000, duration_minutes: 10, calories: 100)
                    ]
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        // Update cardio log
        viewModel.draftExercises[0].sets[0].distanceText = "1200"
        
        await viewModel.saveChanges()
        
        XCTAssertTrue(dataManager.updateCardioLogCalled)
        XCTAssertEqual(dataManager.lastUpdatedCardioLog?.distance_meters, 1200)
    }

    func testSaveChangesWithNewCardioLog() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 2,
                    exerciseName: "Running",
                    exerciseType: .duration,
                    sets: [],
                    cardioLogs: []
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        // Add new cardio log (which is treated as a "set" in the draft)
        viewModel.addSet(to: 2)
        viewModel.draftExercises[0].sets[0].distanceText = "500"
        
        await viewModel.saveChanges()
        
        XCTAssertTrue(dataManager.createCardioLogCalled)
        XCTAssertEqual(dataManager.lastCreatedCardioLogRequest?.distance_meters, 500)
    }

    func testSupersetPreservation() async {
        let sessionId: Int64 = 123
        let detail = WorkoutSessionDetail(
            session: WorkoutSession(id: sessionId, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutSessionExerciseDetail(
                    exerciseId: 1,
                    exerciseName: "Squat",
                    exerciseType: .repBased,
                    sets: [
                        WorkoutSet(id: 10, workout_session_id: sessionId, exercise_id: 1, set_number: 1, reps: 10, weight: 100, superset_group_id: 1)
                    ],
                    cardioLogs: []
                )
            ]
        )
        
        let dataManager = FakeWorkoutSessionDetailDataManager(detail: detail)
        let viewModel = WorkoutSessionDetailViewModel(sessionId: sessionId, dataManager: dataManager)
        
        await viewModel.load()
        viewModel.startEditing()
        
        XCTAssertEqual(viewModel.draftExercises[0].sets[0].superset_group_id, 1)
        
        viewModel.draftExercises[0].sets[0].weightText = "110"
        
        await viewModel.saveChanges()
        
        XCTAssertEqual(dataManager.lastUpdatedSet?.superset_group_id, 1)
    }
}

private final class FakeWorkoutSessionDetailDataManager: WorkoutDataManaging {
    var detail: WorkoutSessionDetail
    
    var updateWorkoutSessionCalled = false
    var lastUpdatedSession: WorkoutSession?
    
    var updateWorkoutSetCalled = false
    var lastUpdatedSet: WorkoutSet?
    
    var createWorkoutSetCalled = false
    var lastCreatedSetRequest: CreateWorkoutSetRequest?
    
    var deleteWorkoutSetCalled = false
    var deletedSetIds: [Int64] = []
    
    var updateCardioLogCalled = false
    var lastUpdatedCardioLog: CardioLog?
    
    var createCardioLogCalled = false
    var lastCreatedCardioLogRequest: CreateCardioLogRequest?
    
    var deleteCardioLogCalled = false
    var deletedCardioLogIds: [Int64] = []
    
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
        lastCreatedSetRequest = request
        return WorkoutSet(id: 999, workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, set_number: request.set_number, reps: request.reps, weight: request.weight, superset_group_id: request.superset_group_id)
    }
    
    func deleteWorkoutSet(id: Int64) async throws {
        deleteWorkoutSetCalled = true
        deletedSetIds.append(id)
    }

    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog {
        updateCardioLogCalled = true
        lastUpdatedCardioLog = log
        return log
    }

    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        createCardioLogCalled = true
        lastCreatedCardioLogRequest = request
        return CardioLog(id: 888, workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, distance_meters: request.distance_meters, duration_minutes: request.duration_minutes, calories: request.calories)
    }

    func deleteCardioLog(id: Int64) async throws {
        deleteCardioLogCalled = true
        deletedCardioLogIds.append(id)
    }

    // Required by protocol but not used in these tests
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] { [] }
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession { detail.session }
    func deleteWorkoutSession(id: Int64) async throws {}
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] { [] }
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [detail.session] }
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult] { [] }

    func fetchFitnessHomeBundle(daysBack: Int) async throws -> FitnessHomeBundle { fatalError("Not implemented") }
    func fetchFitnessAnalysisSummary(daysBack: Int) async throws -> FitnessAnalysisSummaryResponse { fatalError("Not implemented") }
    func fetchWorkoutRoutinesSummary() async throws -> [WorkoutTemplateSummary] { [] }
    func fetchLatestExerciseHistory(exerciseIds: [Int64]) async throws -> [WorkoutSet] { [] }
}
