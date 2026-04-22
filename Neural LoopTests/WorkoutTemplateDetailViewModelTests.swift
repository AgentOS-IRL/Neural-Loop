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
        dataManager.shouldFailFetchingExercises = true

        let viewModel = WorkoutTemplateDetailViewModel(
            summary: WorkoutTemplateSummary(id: 400, title: "Fail Day", exerciseCount: 0, setCount: 0),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.errorMessage, "Unable to load workout details.")
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

private final class FakeWorkoutTemplateDetailDataManager: WorkoutDataManaging {
    var equipment: [Equipment]
    var exercises: [Exercise]
    var routineExercisesByRoutineID: [Int64: [RoutineExercise]]
    var shouldFailFetchingExercises = false

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

    func fetchAllExercises() async throws -> [Exercise] {
        if shouldFailFetchingExercises {
            throw FakeWorkoutTemplateDetailError.unableToLoadWorkoutDetails
        }

        return exercises
    }

    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        fatalError("Not used in detail view model tests.")
    }

    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        fatalError("Not used in detail view model tests.")
    }

    func deleteWorkoutSession(id: Int64) async throws {
        fatalError("Not used in detail view model tests.")
    }
}

extension FakeWorkoutTemplateDetailDataManager: FitnessTemplateDataManaging {
    func fetchAllRoutines() async throws -> [Routine] {
        []
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        routineExercisesByRoutineID[routineId] ?? []
    }
}

private enum FakeWorkoutTemplateDetailError: LocalizedError {
    case unableToLoadWorkoutDetails

    var errorDescription: String? {
        switch self {
        case .unableToLoadWorkoutDetails:
            return "Unable to load workout details."
        }
    }
}
