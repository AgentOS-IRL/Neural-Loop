import XCTest
@testable import Neural_Loop

@MainActor
final class FitnessViewModelWatchActionTests: XCTestCase {
    
    var db: FakeFitnessViewModelDataManager!
    var persistenceManager: WorkoutDraftPersistenceManager!
    var connectivityProvider: FakeConnectivityProvider!
    
    override func setUp() {
        super.setUp()
        db = FakeFitnessViewModelDataManager()
        connectivityProvider = FakeConnectivityProvider()
        let userDefaults = UserDefaults(suiteName: "FitnessViewModelWatchActionTests")!
        userDefaults.removePersistentDomain(forName: "FitnessViewModelWatchActionTests")
        persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
    }
    
    func testRoutingToActionToActiveViewModel() async {
        let routineID: Int64 = 42
        let draft = ActiveWorkoutDraft(
            routineID: routineID,
            session: WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutExerciseCardState(
                    id: 10,
                    exercise: ExerciseLibraryItem(id: 10, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None"),
                    sets: [WorkoutSetDraft(setNumber: 1)]
                )
            ]
        )
        
        let viewModel = FitnessViewModel(
            dataManager: db,
            persistenceManager: persistenceManager,
            connectivityManager: connectivityProvider
        )
        
        // Setup active view model
        viewModel.activeViewModel = ActiveWorkoutViewModel(
            draft: draft,
            db: db,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
        
        let setUUID = draft.exercises[0].sets[0].id
        let action = WorkoutWatchAction(payload: .updateSetValues(WorkoutWatchSetValuesAction(
            reference: WorkoutWatchSetReference(
                session: draft.watchSessionPointer,
                exerciseID: "10",
                setID: setUUID.uuidString
            ),
            values: WorkoutSetValuesSnapshot(kg: 100, reps: 5)
        )))
        
        viewModel.handleWatchAction(action)
        
        // Wait for async task in handleWatchAction
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(viewModel.activeViewModel?.draft.exercises[0].sets[0].weightText, "100")
        XCTAssertEqual(connectivityProvider.sendCount, 1)
    }
    
    func testRoutingToPersistenceIfNoViewModelActive() async {
        let routineID: Int64 = 42
        let draft = ActiveWorkoutDraft(
            routineID: routineID,
            session: WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutExerciseCardState(
                    id: 10,
                    exercise: ExerciseLibraryItem(id: 10, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None"),
                    sets: [WorkoutSetDraft(setNumber: 1)]
                )
            ]
        )
        persistenceManager.save(draft: draft)
        
        let viewModel = FitnessViewModel(
            dataManager: db,
            persistenceManager: persistenceManager,
            connectivityManager: connectivityProvider
        )
        
        XCTAssertNil(viewModel.activeViewModel)
        
        let setUUID = draft.exercises[0].sets[0].id
        let action = WorkoutWatchAction(payload: .updateSetValues(WorkoutWatchSetValuesAction(
            reference: WorkoutWatchSetReference(
                session: draft.watchSessionPointer,
                exerciseID: "10",
                setID: setUUID.uuidString
            ),
            values: WorkoutSetValuesSnapshot(kg: 100, reps: 5)
        )))
        
        viewModel.handleWatchAction(action)
        
        // Wait for async task
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let updatedDraft = persistenceManager.load(routineID: routineID)
        XCTAssertEqual(updatedDraft?.exercises[0].sets[0].weightText, "100")
    }
    
    func testFallbackSnapshotRequest() async {
        let routineID: Int64 = 42
        let draft = ActiveWorkoutDraft(
            routineID: routineID,
            session: WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: []
        )
        persistenceManager.save(draft: draft)
        
        let viewModel = FitnessViewModel(
            dataManager: db,
            persistenceManager: persistenceManager,
            connectivityManager: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .requestSnapshot(WorkoutWatchSessionAction(
            session: draft.watchSessionPointer
        )))
        
        viewModel.handleWatchAction(action)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(connectivityProvider.sendCount, 1)
        XCTAssertEqual(connectivityProvider.capturedSnapshot?.session.id, draft.watchSessionPointer.id)
    }
    
    func testFallbackFinishWorkout() async {
        let routineID: Int64 = 42
        let draft = ActiveWorkoutDraft(
            routineID: routineID,
            session: WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: [
                WorkoutExerciseCardState(
                    id: 10,
                    exercise: ExerciseLibraryItem(id: 10, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None"),
                    sets: [WorkoutSetDraft(setNumber: 1, repsText: "10")]
                )
            ]
        )
        persistenceManager.save(draft: draft)
        
        let viewModel = FitnessViewModel(
            dataManager: db,
            persistenceManager: persistenceManager,
            connectivityManager: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .finishWorkout(WorkoutWatchSessionAction(
            session: draft.watchSessionPointer
        )))
        
        viewModel.handleWatchAction(action)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNil(persistenceManager.load(routineID: routineID))
    }
}

class FakeFitnessViewModelDataManager: FitnessTemplateDataManaging, WorkoutDataManaging {
    func updateRoutine(_ routine: Routine) async throws -> Routine { routine }
    func fetchRoutine(by id: Int64) async throws -> Routine? { nil }
    func fetchAllRoutines() async throws -> [Routine] { [] }
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] { [] }
    
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] { [] }
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        WorkoutSession(id: 1, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
    }
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        WorkoutSet(id: 1, workout_session_id: 1, exercise_id: 1, set_number: 1, reps: 1, weight: nil, superset_group_id: nil)
    }
    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        CardioLog(id: 1, workout_session_id: 1, exercise_id: 1, distance_meters: nil, duration_minutes: nil, calories: nil)
    }
    func deleteWorkoutSession(id: Int64) async throws {}
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] { [] }
    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [] }
    func fetchWorkoutSessionDetail(sessionId: Int64) async throws -> WorkoutSessionDetail {
        throw WorkoutDatabaseError.missingIdentifier
    }
    func fetchExerciseProgression(exerciseId: Int64) async throws -> [ExerciseProgressionResult] { [] }
    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession { session }
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet { set }
    func deleteWorkoutSet(id: Int64) async throws {}
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog { log }
    func deleteCardioLog(id: Int64) async throws {}
}
