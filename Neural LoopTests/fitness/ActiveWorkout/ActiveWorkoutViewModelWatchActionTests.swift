import XCTest
@testable import Neural_Loop

@MainActor
final class ActiveWorkoutViewModelWatchActionTests: XCTestCase {
    
    var db: FakeWorkoutDataManager!
    var connectivityProvider: FakeConnectivityProvider!
    var persistenceManager: WorkoutDraftPersistenceManager!
    
    override func setUp() {
        super.setUp()
        db = FakeWorkoutDataManager()
        connectivityProvider = FakeConnectivityProvider()
        let userDefaults = UserDefaults(suiteName: "ActiveWorkoutWatchActionTests")!
        userDefaults.removePersistentDomain(forName: "ActiveWorkoutWatchActionTests")
        persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
    }
    
    func testApplyUpdateSetValues() async {
        let exerciseID: Int64 = 10
        let setUUID = UUID()
        let draft = makeDraft(exercises: [
            makeExerciseState(id: exerciseID, sets: [
                WorkoutSetDraft(id: setUUID, setNumber: 1, weightText: "50", repsText: "10")
            ])
        ])
        let viewModel = ActiveWorkoutViewModel(
            draft: draft,
            db: db,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .updateSetValues(WorkoutWatchSetValuesAction(
            reference: WorkoutWatchSetReference(
                session: viewModel.draft.watchSessionPointer,
                exerciseID: "\(exerciseID)",
                setID: setUUID.uuidString
            ),
            values: WorkoutSetValuesSnapshot(kg: 60, reps: 12)
        )))
        
        await viewModel.apply(watchAction: action)
        
        XCTAssertEqual(viewModel.draft.exercises[0].sets[0].weightText, "60")
        XCTAssertEqual(viewModel.draft.exercises[0].sets[0].repsText, "12")
        XCTAssertEqual(connectivityProvider.sendCount, 1)
        XCTAssertEqual(connectivityProvider.capturedSnapshot?.exercises[0].sets[0].values.kg, 60)
    }
    
    func testApplyAddSet() async {
        let exerciseID: Int64 = 10
        let draft = makeDraft(exercises: [
            makeExerciseState(id: exerciseID, sets: [
                WorkoutSetDraft(setNumber: 1, weightText: "50", repsText: "10")
            ])
        ])
        let viewModel = ActiveWorkoutViewModel(
            draft: draft,
            db: db,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .addSet(WorkoutWatchExerciseReference(
            session: viewModel.draft.watchSessionPointer,
            exerciseID: "\(exerciseID)"
        )))
        
        await viewModel.apply(watchAction: action)
        
        XCTAssertEqual(viewModel.draft.exercises[0].sets.count, 2)
        XCTAssertEqual(viewModel.draft.exercises[0].sets[1].setNumber, 2)
        XCTAssertEqual(viewModel.draft.exercises[0].sets[1].weightText, "50")
        XCTAssertEqual(connectivityProvider.sendCount, 1)
    }
    
    func testApplyToggleSetCompletion() async {
        let exerciseID: Int64 = 10
        let setUUID = UUID()
        var exercise = makeExerciseState(id: exerciseID, sets: [
            WorkoutSetDraft(id: setUUID, setNumber: 1, isCompleted: false)
        ])
        exercise.restSeconds = 60
        let draft = makeDraft(exercises: [exercise])
        let viewModel = ActiveWorkoutViewModel(
            draft: draft,
            db: db,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .toggleSetCompletion(WorkoutWatchSetCompletionAction(
            reference: WorkoutWatchSetReference(
                session: viewModel.draft.watchSessionPointer,
                exerciseID: "\(exerciseID)",
                setID: setUUID.uuidString
            ),
            isCompleted: true
        )))
        
        await viewModel.apply(watchAction: action)
        
        XCTAssertTrue(viewModel.draft.exercises[0].sets[0].isCompleted)
        XCTAssertTrue(viewModel.isTimerRunning)
        XCTAssertEqual(connectivityProvider.sendCount, 1)
    }
    
    func testApplyCompleteExercise() async {
        let exerciseID: Int64 = 10
        let draft = makeDraft(exercises: [
            makeExerciseState(id: exerciseID, sets: [
                WorkoutSetDraft(setNumber: 1, isCompleted: false),
                WorkoutSetDraft(setNumber: 2, isCompleted: false)
            ])
        ])
        let viewModel = ActiveWorkoutViewModel(
            draft: draft,
            db: db,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(
            reference: WorkoutWatchExerciseReference(
                session: viewModel.draft.watchSessionPointer,
                exerciseID: "\(exerciseID)"
            ),
            isCompleted: true
        )))
        
        await viewModel.apply(watchAction: action)
        
        XCTAssertTrue(viewModel.draft.exercises[0].sets.allSatisfy(\.isCompleted))
        XCTAssertEqual(connectivityProvider.sendCount, 1)
    }
    
    func testApplyFinishWorkout() async {
        let draft = makeDraft(routineID: 42, exercises: [])
        persistenceManager.save(draft: draft)
        
        let viewModel = ActiveWorkoutViewModel(
            draft: draft,
            db: db,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
        
        let action = WorkoutWatchAction(payload: .finishWorkout(WorkoutWatchSessionAction(
            session: viewModel.draft.watchSessionPointer
        )))
        
        await viewModel.apply(watchAction: action)
        
        XCTAssertNotNil(db.capturedSessionRequest)
        XCTAssertNil(persistenceManager.load(routineID: 42))
    }
    
    func testInvalidIDsGracefullyHandled() async {
        let draft = makeDraft(exercises: [
            makeExerciseState(id: 10, sets: [WorkoutSetDraft(setNumber: 1)])
        ])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db, connectivityProvider: connectivityProvider)
        
        // Invalid Exercise ID
        let action1 = WorkoutWatchAction(payload: .addSet(WorkoutWatchExerciseReference(
            session: viewModel.draft.watchSessionPointer,
            exerciseID: "999"
        )))
        await viewModel.apply(watchAction: action1)
        XCTAssertEqual(viewModel.draft.exercises[0].sets.count, 1)
        
        // Invalid Set ID
        let action2 = WorkoutWatchAction(payload: .toggleSetCompletion(WorkoutWatchSetCompletionAction(
            reference: WorkoutWatchSetReference(
                session: viewModel.draft.watchSessionPointer,
                exerciseID: "10",
                setID: UUID().uuidString
            ),
            isCompleted: true
        )))
        await viewModel.apply(watchAction: action2)
        XCTAssertFalse(viewModel.draft.exercises[0].sets[0].isCompleted)
    }
    
    func testIdempotentCompletion() async {
        let exerciseID: Int64 = 10
        let setUUID = UUID()
        let draft = makeDraft(exercises: [
            makeExerciseState(id: exerciseID, sets: [
                WorkoutSetDraft(id: setUUID, setNumber: 1, isCompleted: true)
            ])
        ])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db, connectivityProvider: connectivityProvider)
        
        let action = WorkoutWatchAction(payload: .toggleSetCompletion(WorkoutWatchSetCompletionAction(
            reference: WorkoutWatchSetReference(
                session: viewModel.draft.watchSessionPointer,
                exerciseID: "\(exerciseID)",
                setID: setUUID.uuidString
            ),
            isCompleted: true // Already completed
        )))
        
        await viewModel.apply(watchAction: action)
        
        // Should NOT toggle back to false
        XCTAssertTrue(viewModel.draft.exercises[0].sets[0].isCompleted)
        // Should NOT send snapshot as no change occurred (per implementation)
        // Wait, my implementation of toggleSetCompletion calls persistDraft() if changed.
        // Let's check ActiveWorkoutViewModel.apply:
        /*
        case .toggleSetCompletion(let action):
            if set.isCompleted != action.isCompleted {
                toggleSetCompletion(exerciseID: exerciseID, setID: setUUID)
            }
        */
        // So it shouldn't call toggleSetCompletion, thus no persistDraft, no snapshot.
        XCTAssertEqual(connectivityProvider.sendCount, 0)
    }
    
    func testStaleSessionIDIsIgnored() async {
        let draft = makeDraft(exercises: [
            makeExerciseState(id: 10, sets: [WorkoutSetDraft(setNumber: 1)])
        ])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db, connectivityProvider: connectivityProvider)
        
        // Create an action with a different session ID (simulating a previous run)
        let staleSession = WorkoutSessionPointer(id: "stale-id", routineID: draft.routineID)
        let action = WorkoutWatchAction(payload: .addSet(WorkoutWatchExerciseReference(
            session: staleSession,
            exerciseID: "10"
        )))
        
        await viewModel.apply(watchAction: action)
        
        // Should NOT add a set
        XCTAssertEqual(viewModel.draft.exercises[0].sets.count, 1)
        XCTAssertEqual(connectivityProvider.sendCount, 0)
    }
    
    // MARK: - Helpers
    
    private func makeDraft(
        routineID: Int64 = 1,
        exercises: [WorkoutExerciseCardState] = [],
        updatedAt: Date = Date()
    ) -> ActiveWorkoutDraft {
        ActiveWorkoutDraft(
            routineID: routineID,
            session: WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil),
            exercises: exercises,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: updatedAt
        )
    }
    
    private func makeExerciseState(id: Int64, sets: [WorkoutSetDraft]) -> WorkoutExerciseCardState {
        WorkoutExerciseCardState(
            id: id,
            exercise: ExerciseLibraryItem(id: id, name: "Exercise \(id)", type: .repBased, equipmentID: nil, equipmentName: "None"),
            sets: sets
        )
    }
}

class FakeConnectivityProvider: WorkoutConnectivityProviding {
    var capturedSnapshot: ActiveWorkoutSnapshot?
    var capturedAction: WorkoutWatchAction?
    var capturedFinalizedResult: WorkoutFinalizedResult?
    var sendCount = 0
    var clearCount = 0
    
    func sendWorkoutSnapshot(_ snapshot: ActiveWorkoutSnapshot, completion: ((Result<Void, Error>) -> Void)?) {
        capturedSnapshot = snapshot
        sendCount += 1
        completion?(.success(()))
    }
    
    func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)?) {
        capturedAction = action
        completion?(.success(()))
    }
    
    func sendWorkoutFinalizedResult(_ result: WorkoutFinalizedResult, completion: ((Result<Void, Error>) -> Void)?) {
        capturedFinalizedResult = result
        completion?(.success(()))
    }
    
    func clearWorkoutSnapshot() {
        clearCount += 1
    }
}
