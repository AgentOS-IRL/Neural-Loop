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

private final class FakeFitnessTemplateDataManager: FitnessTemplateDataManaging {
    var routines: [Routine]
    var exercisesByRoutineID: [Int64: [RoutineExercise]]
    var shouldFailFetchingRoutines = false

    init(routines: [Routine], exercisesByRoutineID: [Int64: [RoutineExercise]]) {
        self.routines = routines
        self.exercisesByRoutineID = exercisesByRoutineID
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
