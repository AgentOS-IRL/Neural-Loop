import XCTest
@testable import Neural_Loop

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
    
    func testFinishWorkoutSavesSessionAndSetsWithValidReps() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 10, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None")
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, weightText: "100", repsText: "10"),
            WorkoutSetDraft(setNumber: 2, weightText: "100", repsText: "0"), // Should be ignored
            WorkoutSetDraft(setNumber: 3, weightText: "110", repsText: "8")
        ])
        
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertNotNil(db.capturedSessionRequest)
        XCTAssertEqual(db.capturedSessionRequest?.session_type, "Test")
        XCTAssertEqual(db.capturedSetRequests.count, 2)
        
        XCTAssertEqual(db.capturedSetRequests[0].exercise_id, 10)
        XCTAssertEqual(db.capturedSetRequests[0].reps, 10)
        XCTAssertEqual(db.capturedSetRequests[0].weight, 100)
        
        XCTAssertEqual(db.capturedSetRequests[1].reps, 8)
        XCTAssertEqual(db.capturedSetRequests[1].weight, 110)
        
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpdateDurationUpdatesState() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .duration, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)

        viewModel.updateDuration(for: 1, setID: set.id, durationText: "15.5")

        XCTAssertEqual(viewModel.draft.exercises[0].sets[0].durationText, "15.5")
    }

    func testUpdateDistanceUpdatesState() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .duration, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)

        viewModel.updateDistance(for: 1, setID: set.id, distanceText: "5.2")

        XCTAssertEqual(viewModel.draft.exercises[0].sets[0].distanceText, "5.2")
    }

    func testUpdateCaloriesUpdatesState() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .duration, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)

        viewModel.updateCalories(for: 1, setID: set.id, caloriesText: "500")

        XCTAssertEqual(viewModel.draft.exercises[0].sets[0].caloriesText, "500")
    }

    func testDraftChangesTriggerCallback() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        let draft = makeDraft(session: session, exercises: [state])
        
        var callbackDraft: ActiveWorkoutDraft?
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db) { updated in
            callbackDraft = updated
        }
        
        viewModel.updateWeight(for: 1, setID: set.id, weightText: "100")
        
        XCTAssertNotNil(callbackDraft)
        XCTAssertEqual(callbackDraft?.exercises[0].sets[0].weightText, "100")
    }

    func testInitialDraftDoesNotTriggerCallback() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let draft = makeDraft(session: session, exercises: [])
        
        var callbackCount = 0
        _ = ActiveWorkoutViewModel(draft: draft, db: db) { _ in
            callbackCount += 1
        }
        
        XCTAssertEqual(callbackCount, 0, "Initial draft emission should be dropped")
    }

    func testOnFinishCallbackIsInvoked() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let draft = makeDraft(session: session, exercises: [])
        
        var finishCalled = false
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db, onFinish: {
            finishCalled = true
        })
        
        await viewModel.finishWorkout()
        
        XCTAssertTrue(finishCalled)
    }

    func testFinishWorkoutSavesCardioLogs() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 20, name: "Running", type: .duration, equipmentID: nil, equipmentName: "None")
        let state = WorkoutExerciseCardState(id: 2, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, durationText: "30"),
            WorkoutSetDraft(setNumber: 2, durationText: "0"), // Should be ignored
            WorkoutSetDraft(setNumber: 3, durationText: "45")
        ])
        
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertEqual(db.capturedCardioRequests.count, 2)
        XCTAssertEqual(db.capturedCardioRequests[0].exercise_id, 20)
        XCTAssertEqual(db.capturedCardioRequests[0].duration_minutes, 30)
        XCTAssertEqual(db.capturedCardioRequests[1].duration_minutes, 45)
    }

    func testFinishWorkoutSavesCardioLogsWithDistanceAndCalories() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 20, name: "Running", type: .duration, equipmentID: nil, equipmentName: "None")
        let state = WorkoutExerciseCardState(id: 2, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, durationText: "30", distanceText: "5", caloriesText: "400"),
            WorkoutSetDraft(setNumber: 2, durationText: "", distanceText: "2.5", caloriesText: ""),
            WorkoutSetDraft(setNumber: 3, durationText: "10", distanceText: "", caloriesText: "100")
        ])
        
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertEqual(db.capturedCardioRequests.count, 3)
        
        // Set 1
        XCTAssertEqual(db.capturedCardioRequests[0].duration_minutes, 30)
        XCTAssertEqual(db.capturedCardioRequests[0].distance_meters, 5000)
        XCTAssertNil(db.capturedCardioRequests[0].calories) // Guarded for now
        
        // Set 2
        XCTAssertNil(db.capturedCardioRequests[1].duration_minutes)
        XCTAssertEqual(db.capturedCardioRequests[1].distance_meters, 2500)
        XCTAssertNil(db.capturedCardioRequests[1].calories)
        
        // Set 3
        XCTAssertEqual(db.capturedCardioRequests[2].duration_minutes, 10)
        XCTAssertNil(db.capturedCardioRequests[2].distance_meters)
        XCTAssertNil(db.capturedCardioRequests[2].calories) // Guarded for now
    }

    func testFinishWorkoutSavesCardioLogsWithDecimalDuration() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 20, name: "Running", type: .duration, equipmentID: nil, equipmentName: "None")
        
        // Testing decimal duration
        let state = WorkoutExerciseCardState(id: 2, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, durationText: "15.5")
        ])
        
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertEqual(db.capturedCardioRequests.count, 1)
        XCTAssertEqual(db.capturedCardioRequests[0].duration_minutes, 15.5)
    }
    
    func testFinishWorkoutSetsErrorMessageOnFailure() async {
        let db = FakeWorkoutDataManager()
        db.shouldFail = true
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        
        let draft = makeDraft(session: session, exercises: [])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testToggleSetCompletionStartsTimer() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        var state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        state.restSeconds = 60
        let draft = makeDraft(session: session, exercises: [state])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)

        viewModel.toggleSetCompletion(exerciseID: 1, setID: set.id)

        XCTAssertTrue(viewModel.draft.exercises[0].sets[0].isCompleted)
        XCTAssertTrue(viewModel.isTimerRunning)
        XCTAssertEqual(viewModel.restTimerSeconds, 60)
    }

    func testStopTimerResetsState() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let draft = makeDraft(session: session, exercises: [])
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db)

        viewModel.restTimerSeconds = 30
        viewModel.isTimerRunning = true

        viewModel.stopTimer()

        XCTAssertFalse(viewModel.isTimerRunning)
        XCTAssertEqual(viewModel.restTimerSeconds, 0)
    }

    func testMutationUpdatesTimestampAndSavesRoutineDraft() async {
        let db = FakeWorkoutDataManager()
        let userDefaults = UserDefaults(suiteName: "ActiveWorkoutMutationPersistence")!
        userDefaults.removePersistentDomain(forName: "ActiveWorkoutMutationPersistence")
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        let originalUpdatedAt = Date(timeIntervalSinceNow: -60)
        let draft = makeDraft(routineID: 42, session: session, exercises: [state], updatedAt: originalUpdatedAt)
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db, persistenceManager: persistenceManager)

        viewModel.updateReps(for: 1, setID: set.id, repsText: "12")

        let savedDraft = persistenceManager.load(routineID: 42)
        XCTAssertEqual(savedDraft?.exercises[0].sets[0].repsText, "12")
        XCTAssertGreaterThan(viewModel.draft.updatedAt, originalUpdatedAt)
        XCTAssertEqual(savedDraft?.updatedAt, viewModel.draft.updatedAt)
    }

    func testFinishWorkoutClearsOnlyFinishedRoutineDraft() async {
        let db = FakeWorkoutDataManager()
        let userDefaults = UserDefaults(suiteName: "ActiveWorkoutFinishClearsOnlyRoutine")!
        userDefaults.removePersistentDomain(forName: "ActiveWorkoutFinishClearsOnlyRoutine")
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: nil)
        let finishedDraft = makeDraft(routineID: 1, session: session)
        let otherDraft = makeDraft(routineID: 2, session: session)
        persistenceManager.save(draft: finishedDraft)
        persistenceManager.save(draft: otherDraft)
        let viewModel = ActiveWorkoutViewModel(draft: finishedDraft, db: db, persistenceManager: persistenceManager)

        await viewModel.finishWorkout()

        XCTAssertNil(persistenceManager.load(routineID: 1))
        XCTAssertNotNil(persistenceManager.load(routineID: 2))
    }

    func testFinishWorkoutFailureLeavesDraftPersisted() async {
        let db = FakeWorkoutDataManager()
        db.shouldFail = true
        let userDefaults = UserDefaults(suiteName: "ActiveWorkoutFailureLeavesDraft")!
        userDefaults.removePersistentDomain(forName: "ActiveWorkoutFailureLeavesDraft")
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let draft = makeDraft(routineID: 1, session: session)
        persistenceManager.save(draft: draft)
        let viewModel = ActiveWorkoutViewModel(draft: draft, db: db, persistenceManager: persistenceManager)

        await viewModel.finishWorkout()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNotNil(persistenceManager.load(routineID: 1))
    }

    private func makeDraft(
        routineID: Int64 = 1,
        session: WorkoutSession,
        exercises: [WorkoutExerciseCardState] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> ActiveWorkoutDraft {
        ActiveWorkoutDraft(
            routineID: routineID,
            session: session,
            exercises: exercises,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

class FakeWorkoutDataManager: WorkoutCatalogReading, WorkoutLaunchHistoryReading, WorkoutFinalizationPersisting {
    var shouldFail = false
    var capturedSessionRequest: CreateWorkoutSessionRequest?
    var capturedSetRequests: [CreateWorkoutSetRequest] = []
    var capturedCardioRequests: [CreateCardioLogRequest] = []
    
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] { [] }
    
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        capturedSessionRequest = request
        return WorkoutSession(id: 123, date: request.date ?? Date(), start_time: request.start_time, end_time: request.end_time, session_type: request.session_type, notes: request.notes)
    }
    
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        capturedSetRequests.append(request)
        return WorkoutSet(id: Int64(capturedSetRequests.count), workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, set_number: request.set_number, reps: request.reps, weight: request.weight, superset_group_id: request.superset_group_id)
    }

    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        capturedCardioRequests.append(request)
        return CardioLog(id: Int64(capturedCardioRequests.count), workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, distance_meters: request.distance_meters, duration_minutes: request.duration_minutes, calories: request.calories)
    }
    
    func deleteWorkoutSession(id: Int64) async throws {}
    
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] {
        return []
    }

    func fetchWorkoutSessions() async throws -> [WorkoutSession] { [] }

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

extension FakeWorkoutDataManager {
    func fetchWorkoutLaunchHistory(
        routineID: Int64?,
        lookupItems: [WorkoutLaunchHistoryLookupItem]
    ) async throws -> [WorkoutLaunchHistorySnapshot] {
        []
    }

    func finalizeWorkout(_ payload: FinalizeWorkoutPayload) async throws -> FinalizeWorkoutResponse {
        if shouldFail {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"])
        }
        capturedSessionRequest = CreateWorkoutSessionRequest(
            date: WorkoutDateCoding.date(from: payload.session.date),
            start_time: payload.session.start_time,
            end_time: payload.session.end_time,
            session_type: payload.session.session_type,
            notes: payload.session.notes,
            routine_id: payload.routine_id
        )
        capturedSetRequests = payload.sets.map {
            CreateWorkoutSetRequest(
                workout_session_id: 123,
                exercise_id: $0.exercise_id,
                set_number: $0.set_number,
                reps: $0.reps,
                weight: $0.weight,
                superset_group_id: $0.superset_group_id,
                routine_exercise_id: $0.routine_exercise_id,
                set_type: $0.set_type
            )
        }
        capturedCardioRequests = payload.cardio_logs.map {
            CreateCardioLogRequest(
                workout_session_id: 123,
                exercise_id: $0.exercise_id,
                distance_meters: $0.distance_meters,
                duration_minutes: $0.duration_minutes,
                calories: $0.calories,
                routine_exercise_id: $0.routine_exercise_id,
                set_number: $0.set_number
            )
        }
        return FinalizeWorkoutResponse(session_id: 123)
    }
}
