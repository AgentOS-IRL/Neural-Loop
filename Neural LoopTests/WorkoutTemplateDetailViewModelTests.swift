import XCTest
@testable import Neural_Loop

@MainActor
final class WorkoutTemplateDetailViewModelTests: XCTestCase {
    func testLoadMapsRoutineExercisesToRows() async {
        let dataManager = FakeWorkoutTemplateDetailDataManager(
            equipment: [
                equipment(id: 1, name: "Barbell"),
                equipment(id: 2, name: "Cable")
            ],
            exercises: [
                exercise(id: 10, name: "Bench Press", equipmentID: 1),
                exercise(id: 20, name: "Cable Row", equipmentID: 2)
            ],
            routineExercisesByRoutineID: [
                100: [
                    routineExercise(id: 1, routineID: 100, exerciseID: 10, orderIndex: 2, targetSets: 3),
                    routineExercise(id: 2, routineID: 100, exerciseID: 20, orderIndex: 1, targetSets: 4)
                ]
            ]
        )
        dataManager.routinesByID = [
            100: Routine(id: 100, name: "Push Day", notes: nil)
        ]
        let viewModel = WorkoutTemplateDetailViewModel(
            summary: WorkoutTemplateSummary(id: 100, title: "Push Day", exerciseCount: 2, setCount: 7),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(
            viewModel.rows,
            [
                WorkoutTemplateExerciseRow(
                    id: 2,
                    exerciseName: "Cable Row",
                    equipmentName: "Cable",
                    setCount: 4,
                    orderIndex: 1
                ),
                WorkoutTemplateExerciseRow(
                    id: 1,
                    exerciseName: "Bench Press",
                    equipmentName: "Barbell",
                    setCount: 3,
                    orderIndex: 2
                )
            ]
        )
    }

    func testLoadSortsRowsByOrderIndex() async {
        let dataManager = FakeWorkoutTemplateDetailDataManager(
            equipment: [equipment(id: 1, name: "Machine")],
            exercises: [
                exercise(id: 10, name: "Leg Extension", equipmentID: 1),
                exercise(id: 20, name: "Leg Curl", equipmentID: 1)
            ],
            routineExercisesByRoutineID: [
                200: [
                    routineExercise(id: 1, routineID: 200, exerciseID: 20, orderIndex: 3, targetSets: 2),
                    routineExercise(id: 2, routineID: 200, exerciseID: 10, orderIndex: 1, targetSets: 2)
                ]
            ]
        )
        dataManager.routinesByID = [
            200: Routine(id: 200, name: "Leg Day", notes: nil)
        ]
        let viewModel = WorkoutTemplateDetailViewModel(
            summary: WorkoutTemplateSummary(id: 200, title: "Leg Day", exerciseCount: 2, setCount: 4),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.rows.map(\.orderIndex), [1, 3])
        XCTAssertEqual(viewModel.rows.map(\.exerciseName), ["Leg Extension", "Leg Curl"])
    }

    func testLoadUsesFallbackSetCountWhenTargetSetsIsMissing() async {
        let dataManager = FakeWorkoutTemplateDetailDataManager(
            equipment: [equipment(id: 1, name: "Bodyweight")],
            exercises: [exercise(id: 10, name: "Push Up", equipmentID: 1)],
            routineExercisesByRoutineID: [
                300: [
                    routineExercise(id: 1, routineID: 300, exerciseID: 10, orderIndex: 1, targetSets: nil)
                ]
            ]
        )
        dataManager.routinesByID = [
            300: Routine(id: 300, name: "Upper Body", notes: nil)
        ]
        let viewModel = WorkoutTemplateDetailViewModel(
            summary: WorkoutTemplateSummary(id: 300, title: "Upper Body", exerciseCount: 1, setCount: 1),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.rows.first?.setCount, 1)
        XCTAssertEqual(viewModel.rows.first?.setText, "1 set")
    }

    func testLoadSurfacesReadableErrorMessage() async {
        let dataManager = FakeWorkoutTemplateDetailDataManager(
            equipment: [],
            exercises: [],
            routineExercisesByRoutineID: [:]
        )
        dataManager.routinesByID = [
            400: Routine(id: 400, name: "Fail Day", notes: nil)
        ]
        dataManager.shouldFailFetchingExercises = true

        let viewModel = WorkoutTemplateDetailViewModel(
            summary: WorkoutTemplateSummary(id: 400, title: "Fail Day", exerciseCount: 0, setCount: 0),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "Unable to load template details.")
        XCTAssertTrue(viewModel.rows.isEmpty)
    }

    private func equipment(id: Int64, name: String) -> Equipment {
        Equipment(id: id, name: name)
    }

    private func exercise(id: Int64, name: String, equipmentID: Int64?) -> Exercise {
        Exercise(id: id, name: name, type: .repBased, equipment_id: equipmentID, notes: nil)
    }

    private func routineExercise(
        id: Int64,
        routineID: Int64,
        exerciseID: Int64,
        orderIndex: Int,
        targetSets: Int?
    ) -> RoutineExercise {
        RoutineExercise(
            id: id,
            routine_id: routineID,
            exercise_id: exerciseID,
            order_index: orderIndex,
            target_sets: targetSets,
            target_reps: nil,
            rest_seconds: nil,
            superset_group_id: nil,
            duration: nil
        )
    }
}

private final class FakeWorkoutTemplateDetailDataManager: WorkoutTemplateEditingDataManaging, WorkoutDataManaging {
    var equipment: [Equipment]
    var exercises: [Exercise]
    var routinesByID: [Int64: Routine] = [:]
    var routineExercisesByRoutineID: [Int64: [RoutineExercise]]
    var shouldFailFetchingExercises = false
    var createdRoutineRequests: [CreateRoutineRequest] = []
    var updatedRoutineRequests: [Routine] = []
    var deletedRoutineIDs: [Int64] = []
    var createdRoutineExercises: [CreateRoutineExerciseRequest] = []
    var updatedRoutineExercises: [RoutineExercise] = []
    var deletedRoutineExerciseIDs: [Int64] = []

    init(
        equipment: [Equipment],
        exercises: [Exercise],
        routineExercisesByRoutineID: [Int64: [RoutineExercise]]
    ) {
        self.equipment = equipment
        self.exercises = exercises
        self.routineExercisesByRoutineID = routineExercisesByRoutineID
    }

    func fetchAllEquipment() async throws -> [Equipment] {
        equipment
    }

    func fetchAllRoutines() async throws -> [Routine] {
        []
    }

    func fetchRoutine(by id: Int64) async throws -> Routine? {
        routinesByID[id]
    }

    func fetchAllExercises() async throws -> [Exercise] {
        if shouldFailFetchingExercises {
            throw FakeWorkoutTemplateDetailError.unableToLoadWorkoutDetails
        }

        return exercises
    }

    func createRoutine(_ request: CreateRoutineRequest) async throws -> Routine {
        createdRoutineRequests.append(request)
        let routine = Routine(id: 999, name: request.name, notes: request.notes)
        routinesByID[999] = routine
        return routine
    }

    func updateRoutine(_ routine: Routine) async throws -> Routine {
        updatedRoutineRequests.append(routine)
        guard let id = routine.id else {
            return routine
        }

        routinesByID[id] = routine
        return routine
    }

    func deleteRoutine(id: Int64) async throws {
        deletedRoutineIDs.append(id)
        routinesByID[id] = nil
        routineExercisesByRoutineID[id] = nil
    }

    func addRoutineExercise(_ request: CreateRoutineExerciseRequest) async throws -> RoutineExercise {
        createdRoutineExercises.append(request)
        let routineExercise = RoutineExercise(
            id: 9_999,
            routine_id: request.routine_id,
            exercise_id: request.exercise_id,
            order_index: request.order_index,
            target_sets: request.target_sets,
            target_reps: request.target_reps,
            rest_seconds: request.rest_seconds,
            superset_group_id: request.superset_group_id,
            duration: request.duration
        )
        var rows = routineExercisesByRoutineID[request.routine_id] ?? []
        rows.append(routineExercise)
        routineExercisesByRoutineID[request.routine_id] = rows
        return routineExercise
    }

    func updateRoutineExercise(_ routineExercise: RoutineExercise) async throws -> RoutineExercise {
        updatedRoutineExercises.append(routineExercise)
        return routineExercise
    }

    func deleteRoutineExercise(id: Int64) async throws {
        deletedRoutineExerciseIDs.append(id)
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        routineExercisesByRoutineID[routineId] ?? []
    }

    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        WorkoutSession(id: 1, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
    }
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        WorkoutSet(id: 1, workout_session_id: 1, exercise_id: 1, set_number: 1, reps: 1, weight: nil, superset_group_id: nil)
    }
    func deleteWorkoutSession(id: Int64) async throws {}
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] { [] }
}

private enum FakeWorkoutTemplateDetailError: LocalizedError {
    case unableToLoadWorkoutDetails

    var errorDescription: String? {
        switch self {
        case .unableToLoadWorkoutDetails:
            return "Unable to load template details."
        }
    }
}
