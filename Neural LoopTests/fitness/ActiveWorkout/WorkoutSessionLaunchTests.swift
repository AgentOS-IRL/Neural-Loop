import XCTest
@testable import Neural_Loop

@MainActor
final class WorkoutSessionLaunchTests: XCTestCase {
    
    func testLaunchSessionPreparesWorkoutSessionAndExerciseStatesWithoutSaving() async throws {
        let routineID: Int64 = 1
        let routine = Routine(id: routineID, name: "Test Routine", notes: "Some notes")
        let exercises = [
            ExerciseWithMuscles(id: 10, name: "Exercise 1", type: .repBased, equipment_id: 100, notes: nil, exercise_muscles: []),
            ExerciseWithMuscles(id: 11, name: "Exercise 2", type: .repBased, equipment_id: 101, notes: nil, exercise_muscles: [])
        ]
        let equipment = [
            Equipment(id: 100, name: "Dumbbell"),
            Equipment(id: 101, name: "Barbell")
        ]
        let routineExercises = [
            RoutineExercise(id: 1000, routine_id: routineID, exercise_id: 10, order_index: 0, target_sets: 3, target_reps: 10, rest_seconds: 60, superset_group_id: nil, duration: nil),
            RoutineExercise(id: 1001, routine_id: routineID, exercise_id: 11, order_index: 1, target_sets: 4, target_reps: 8, rest_seconds: 90, superset_group_id: nil, duration: nil)
        ]
        
        let db = FakeLaunchDataManager()
        db.stubRoutine = routine
        db.stubExercisesWithMuscles = exercises
        db.stubEquipment = equipment
        db.stubRoutineExercises = routineExercises
        
        let coordinator = WorkoutSessionLaunchCoordinator(
            db: db,
            persistenceManager: makePersistenceManager("TestLaunchSessionPreparesWorkoutSession")
        )
        
        let draft = try await coordinator.launchSession(for: routineID)
        
        XCTAssertNil(draft.session.id)
        XCTAssertEqual(draft.session.session_type, "Test Routine")
        XCTAssertEqual(draft.session.notes, "Some notes")
        XCTAssertEqual(draft.exercises.count, 2)
        
        XCTAssertEqual(draft.exercises[0].exercise.name, "Exercise 1")
        XCTAssertEqual(draft.exercises[0].sets.count, 3)
        
        XCTAssertEqual(draft.exercises[1].exercise.name, "Exercise 2")
        XCTAssertEqual(draft.exercises[1].sets.count, 4)
        
        XCTAssertNil(db.capturedCreateSessionRequest, "Should not create session in DB during launch")
    }

    func testLaunchSavesDraftImmediately() async throws {
        let routineID: Int64 = 1
        let routine = Routine(id: routineID, name: "Test Routine", notes: "Some notes")
        
        let db = FakeLaunchDataManager()
        db.stubRoutine = routine
        
        let persistenceManager = makePersistenceManager("TestLaunchSavesDraftImmediately")
        
        let coordinator = WorkoutSessionLaunchCoordinator(db: db, persistenceManager: persistenceManager)
        
        _ = try await coordinator.launchSession(for: routineID)
        
        let savedDraft = persistenceManager.load(routineID: routineID)
        XCTAssertNotNil(savedDraft)
        XCTAssertEqual(savedDraft?.routineID, routineID)
        XCTAssertEqual(savedDraft?.session.session_type, "Test Routine")
    }

    func testLaunchReturnsExistingValidDraftWithoutFetchingRoutine() async throws {
        let routineID: Int64 = 7
        let persistenceManager = makePersistenceManager("TestLaunchReturnsExistingValidDraft")
        let session = WorkoutSession(id: nil, date: Date(), start_time: "10:00", end_time: nil, session_type: "Saved Draft", notes: nil)
        let existingDraft = ActiveWorkoutDraft(
            routineID: routineID,
            session: session,
            exercises: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        persistenceManager.save(draft: existingDraft)
        let db = FakeLaunchDataManager()
        db.stubRoutine = Routine(id: routineID, name: "Fresh Routine", notes: nil)
        let coordinator = WorkoutSessionLaunchCoordinator(db: db, persistenceManager: persistenceManager)

        let draft = try await coordinator.launchSession(for: routineID)

        XCTAssertEqual(draft.session.session_type, "Saved Draft")
        XCTAssertEqual(db.fetchRoutineCallCount, 0)
    }

    func testLaunchReplacesExpiredDraft() async throws {
        let routineID: Int64 = 8
        let persistenceManager = makePersistenceManager("TestLaunchReplacesExpiredDraft")
        let expiredSession = WorkoutSession(id: nil, date: Date(), start_time: "10:00", end_time: nil, session_type: "Expired Draft", notes: nil)
        let expiredDraft = ActiveWorkoutDraft(
            routineID: routineID,
            session: expiredSession,
            exercises: [],
            createdAt: Date(timeIntervalSinceNow: -90_000),
            updatedAt: Date(timeIntervalSinceNow: -90_000)
        )
        persistenceManager.save(draft: expiredDraft)
        let db = FakeLaunchDataManager()
        db.stubRoutine = Routine(id: routineID, name: "Fresh Routine", notes: nil)
        let coordinator = WorkoutSessionLaunchCoordinator(db: db, persistenceManager: persistenceManager)

        let draft = try await coordinator.launchSession(for: routineID)

        XCTAssertEqual(draft.session.session_type, "Fresh Routine")
        XCTAssertEqual(draft.routineID, routineID)
        XCTAssertEqual(persistenceManager.load(routineID: routineID)?.session.session_type, "Fresh Routine")
        XCTAssertEqual(db.fetchRoutineCallCount, 1)
    }

    func testLaunchSessionClampsNonPositiveTargetSets() async throws {
        let routineID: Int64 = 1
        let routine = Routine(id: routineID, name: "Test", notes: nil)
        let routineExercises = [
            RoutineExercise(id: 1000, routine_id: routineID, exercise_id: 10, order_index: 0, target_sets: 0, target_reps: 10, rest_seconds: 60, superset_group_id: nil, duration: nil),
            RoutineExercise(id: 1001, routine_id: routineID, exercise_id: 11, order_index: 1, target_sets: -5, target_reps: 8, rest_seconds: 90, superset_group_id: nil, duration: nil)
        ]
        
        let db = FakeLaunchDataManager()
        db.stubRoutine = routine
        db.stubExercisesWithMuscles = [
            ExerciseWithMuscles(id: 10, name: "E1", type: .repBased, equipment_id: nil, notes: nil, exercise_muscles: []),
            ExerciseWithMuscles(id: 11, name: "E2", type: .repBased, equipment_id: nil, notes: nil, exercise_muscles: [])
        ]
        db.stubRoutineExercises = routineExercises
        
        let coordinator = WorkoutSessionLaunchCoordinator(
            db: db,
            persistenceManager: makePersistenceManager("TestLaunchSessionClampsNonPositiveTargetSets")
        )
        
        let draft = try await coordinator.launchSession(for: routineID)
        
        XCTAssertEqual(draft.exercises[0].sets.count, 1, "Should clamp 0 to 1")
        XCTAssertEqual(draft.exercises[1].sets.count, 1, "Should clamp negative to 1")
    }
    
    func testLaunchSessionThrowsRoutineNotFoundIfRoutineMissing() async {
        let db = FakeLaunchDataManager()
        db.stubRoutine = nil
        
        let coordinator = WorkoutSessionLaunchCoordinator(
            db: db,
            persistenceManager: makePersistenceManager("TestLaunchSessionThrowsRoutineNotFound")
        )
        
        do {
            _ = try await coordinator.launchSession(for: 1)
            XCTFail("Should have thrown routineNotFound")
        } catch let error as WorkoutLaunchError {
            XCTAssertEqual(error, .routineNotFound)
        } catch {
            XCTFail("Wrong error thrown: \(error)")
        }
    }
    
    func testLaunchSessionPreventsDoubleLaunch() async throws {
        let routineID: Int64 = 1
        let db = FakeLaunchDataManager()
        db.stubRoutine = Routine(id: routineID, name: "Test", notes: nil)
        // Make fetchRoutineExercises slow to trigger re-entrancy
        db.fetchRoutineExercisesDelay = 0.1
        
        let coordinator = WorkoutSessionLaunchCoordinator(
            db: db,
            persistenceManager: makePersistenceManager("TestLaunchSessionPreventsDoubleLaunch")
        )
        
        let expectation1 = expectation(description: "First launch finishes")
        let expectation2 = expectation(description: "Second launch throws")
        
        Task {
            do {
                _ = try await coordinator.launchSession(for: routineID)
                expectation1.fulfill()
            } catch {
                XCTFail("First launch should succeed but failed with \(error)")
            }
        }
        
        // Wait a bit to ensure the first task has started and is suspended at an await
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        Task {
            do {
                _ = try await coordinator.launchSession(for: routineID)
                XCTFail("Second launch should have failed")
            } catch let error as WorkoutLaunchError {
                XCTAssertEqual(error, .launchInProgress)
                expectation2.fulfill()
            } catch {
                XCTFail("Wrong error thrown: \(error)")
            }
        }
        
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
    }

    private func makePersistenceManager(_ suiteName: String) -> WorkoutDraftPersistenceManager {
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return WorkoutDraftPersistenceManager(userDefaults: userDefaults)
    }
}

class FakeLaunchDataManager: WorkoutTemplateReadingDataManaging, WorkoutDataManaging {
    var stubRoutine: Routine?
    var stubExercises: [Exercise] = []
    var stubExercisesWithMuscles: [ExerciseWithMuscles] = []
    var stubEquipment: [Equipment] = []
    var stubRoutineExercises: [RoutineExercise] = []
    var fetchRoutineExercisesDelay: TimeInterval = 0
    var fetchRoutineCallCount = 0
    
    var capturedCreateSessionRequest: CreateWorkoutSessionRequest?
    
    func fetchRoutine(by id: Int64) async throws -> Routine? {
        fetchRoutineCallCount += 1
        stubRoutine
    }
    
    func fetchAllRoutines() async throws -> [Routine] {
        stubRoutine.map { [$0] } ?? []
    }
    
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        if fetchRoutineExercisesDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchRoutineExercisesDelay * 1_000_000_000))
        }
        return stubRoutineExercises
    }
    
    func fetchAllExercises() async throws -> [Exercise] {
        return stubExercises
    }

    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] {
        return stubExercisesWithMuscles
    }

    
    func fetchAllEquipment() async throws -> [Equipment] {
        stubEquipment
    }
    
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        capturedCreateSessionRequest = request
        return WorkoutSession(
            id: 123,
            date: request.date ?? Date(),
            start_time: request.start_time,
            end_time: request.end_time,
            session_type: request.session_type,
            notes: request.notes
        )
    }
    
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        fatalError("Not implemented")
    }

    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        fatalError("Not implemented")
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

    func updateWorkoutSession(_ session: WorkoutSession) async throws -> WorkoutSession { session }
    func updateWorkoutSet(_ set: WorkoutSet) async throws -> WorkoutSet { set }
    func deleteWorkoutSet(id: Int64) async throws {}
    func updateCardioLog(_ log: CardioLog) async throws -> CardioLog { log }
    func deleteCardioLog(id: Int64) async throws {}
}
