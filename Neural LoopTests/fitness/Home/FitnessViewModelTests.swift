import XCTest
@testable import Neural_Loop

@MainActor
final class FitnessViewModelTests: XCTestCase {
    func testLoadMapsRoutinesToTemplateSummaries() async {
        let dataManager = FakeFitnessTemplateDataManager(
            routines: [
                routine(id: 20, name: "Back Day"),
                routine(id: 10, name: "Arms Day")
            ],
            exercisesByRoutineID: [
                10: [
                    routineExercise(id: 1, routineID: 10, orderIndex: 1, targetSets: 2)
                ],
                20: [
                    routineExercise(id: 2, routineID: 20, orderIndex: 1, targetSets: 4),
                    routineExercise(id: 3, routineID: 20, orderIndex: 2, targetSets: nil)
                ]
            ]
        )
        let viewModel = FitnessViewModel(dataManager: dataManager)

        await viewModel.loadIfNeeded()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(
            viewModel.templates,
            [
                WorkoutTemplateSummary(id: 10, title: "Arms Day", exerciseCount: 1, setCount: 2),
                WorkoutTemplateSummary(id: 20, title: "Back Day", exerciseCount: 2, setCount: 5)
            ]
        )
    }

    func testLoadSortsTemplatesAlphabetically() async {
        let dataManager = FakeFitnessTemplateDataManager(
            routines: [
                routine(id: 3, name: "Leg Day"),
                routine(id: 1, name: "Push Day"),
                routine(id: 2, name: "Full Body")
            ],
            exercisesByRoutineID: [
                1: [routineExercise(id: 11, routineID: 1, orderIndex: 1, targetSets: 3)],
                2: [routineExercise(id: 12, routineID: 2, orderIndex: 1, targetSets: 2)],
                3: [routineExercise(id: 13, routineID: 3, orderIndex: 1, targetSets: 4)]
            ]
        )
        let viewModel = FitnessViewModel(dataManager: dataManager)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.templates.map(\.title), ["Full Body", "Leg Day", "Push Day"])
    }

    func testRestoreDraftOnLoad() async {
        let draft = ActiveWorkoutDraft(
            session: WorkoutSession(id: nil, date: Date(), start_time: "10:00", end_time: nil, session_type: "Test", notes: nil),
            exercises: []
        )
        let userDefaults = UserDefaults(suiteName: "TestRestoreDraftOnLoad")!
        userDefaults.removePersistentDomain(forName: "TestRestoreDraftOnLoad")
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        persistenceManager.save(draft: draft)

        let viewModel = FitnessViewModel(
            dataManager: FakeFitnessTemplateDataManager(routines: [], exercisesByRoutineID: [:]),
            persistenceManager: persistenceManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertNotNil(viewModel.activeDraft)
        XCTAssertEqual(viewModel.activeDraft?.session.session_type, "Test")
    }

    func testClearActiveDraftSynchronouslyClearsPersistence() {
        let draft = ActiveWorkoutDraft(
            session: WorkoutSession(id: 1, date: Date(), start_time: "10:00", end_time: nil, session_type: "Test", notes: nil),
            exercises: []
        )
        let userDefaults = UserDefaults(suiteName: "TestClearActiveDraft")!
        userDefaults.removePersistentDomain(forName: "TestClearActiveDraft")
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        persistenceManager.save(draft: draft)

        let viewModel = FitnessViewModel(
            dataManager: FakeFitnessTemplateDataManager(routines: [], exercisesByRoutineID: [:]),
            persistenceManager: persistenceManager
        )

        viewModel.clearActiveDraft()

        XCTAssertNil(viewModel.activeDraft)
        XCTAssertNil(persistenceManager.load(), "Persistence should be cleared immediately")
    }

    func testSaveDraftOnUpdate() async {
        let userDefaults = UserDefaults(suiteName: "TestSaveDraftOnUpdate")!
        userDefaults.removePersistentDomain(forName: "TestSaveDraftOnUpdate")
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        
        let viewModel = FitnessViewModel(
            dataManager: FakeFitnessTemplateDataManager(routines: [], exercisesByRoutineID: [:]),
            persistenceManager: persistenceManager
        )
        
        let draft = ActiveWorkoutDraft(
            session: WorkoutSession(id: 1, date: Date(), start_time: "10:00", end_time: nil, session_type: "Test", notes: nil),
            exercises: []
        )
        
        viewModel.activeDraft = draft
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
        
        let savedDraft = persistenceManager.load()
        XCTAssertNotNil(savedDraft)
        XCTAssertEqual(savedDraft?.session.session_type, "Test")
    }

    func testReloadKeepsPreviousTemplatesWhenFetchingFails() async {
        let dataManager = FakeFitnessTemplateDataManager(
            routines: [routine(id: 1, name: "Push Day")],
            exercisesByRoutineID: [
                1: [routineExercise(id: 11, routineID: 1, orderIndex: 1, targetSets: 3)]
            ]
        )
        let viewModel = FitnessViewModel(dataManager: dataManager)

        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.templates.count, 1)

        dataManager.shouldFailFetchingRoutines = true
        await viewModel.reload()

        XCTAssertEqual(viewModel.templates, [WorkoutTemplateSummary(id: 1, title: "Push Day", exerciseCount: 1, setCount: 3)])
        XCTAssertEqual(viewModel.errorMessage, "Unable to load routines.")
    }

    func testLoadFetchesWorkoutSessions() async {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let dataManager = FakeFitnessTemplateDataManager(
            routines: [],
            exercisesByRoutineID: [:],
            sessions: [
                WorkoutSession(id: 1, date: date1, start_time: nil, end_time: nil, session_type: "Legs", notes: "Hard"),
                WorkoutSession(id: 2, date: date2, start_time: nil, end_time: nil, session_type: "Push", notes: nil)
            ]
        )
        let viewModel = FitnessViewModel(dataManager: dataManager)

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            viewModel.sessions,
            [
                WorkoutSessionSummary(id: 1, date: date1, title: "Legs", notes: "Hard"),
                WorkoutSessionSummary(id: 2, date: date2, title: "Push", notes: nil)
            ]
        )
    }

    private func routine(id: Int64, name: String) -> Routine {
        Routine(id: id, name: name, notes: nil)
    }

    private func routineExercise(
        id: Int64,
        routineID: Int64,
        orderIndex: Int,
        targetSets: Int?
    ) -> RoutineExercise {
        RoutineExercise(
            id: id,
            routine_id: routineID,
            exercise_id: id,
            order_index: orderIndex,
            target_sets: targetSets,
            target_reps: nil,
            rest_seconds: nil,
            superset_group_id: nil,
            duration: nil
        )
    }
}

private final class FakeFitnessTemplateDataManager: FitnessTemplateDataManaging, WorkoutDataManaging {
    var routines: [Routine]
    var exercisesByRoutineID: [Int64: [RoutineExercise]]
    var sessions: [WorkoutSession]
    var shouldFailFetchingRoutines = false

    init(
        routines: [Routine],
        exercisesByRoutineID: [Int64: [RoutineExercise]],
        sessions: [WorkoutSession] = []
    ) {
        self.routines = routines
        self.exercisesByRoutineID = exercisesByRoutineID
        self.sessions = sessions
    }

    func fetchAllRoutines() async throws -> [Routine] {
        if shouldFailFetchingRoutines {
            throw FakeFitnessTemplateError.unableToLoadRoutines
        }

        return routines
    }

    func fetchRoutine(by id: Int64) async throws -> Routine? {
        routines.first { $0.id == id }
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        exercisesByRoutineID[routineId] ?? []
    }

    func updateRoutine(_ routine: Routine) async throws -> Routine {
        guard let id = routine.id else {
            return routine
        }

        if let index = routines.firstIndex(where: { $0.id == id }) {
            routines[index] = routine
        }

        return routine
    }

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
    func fetchWorkoutSessions() async throws -> [WorkoutSession] {
        sessions
    }

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

private enum FakeFitnessTemplateError: LocalizedError {
    case unableToLoadRoutines

    var errorDescription: String? {
        switch self {
        case .unableToLoadRoutines:
            return "Unable to load routines."
        }
    }
}
