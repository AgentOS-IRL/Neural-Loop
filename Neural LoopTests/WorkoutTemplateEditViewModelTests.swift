import XCTest
@testable import Neural_Loop

@MainActor
final class WorkoutTemplateEditViewModelTests: XCTestCase {
    func testSaveUpdatesRoutineRecord() async {
        let dataManager = FakeWorkoutTemplateEditDataManager(
            routineByID: [
                500: Routine(id: 500, name: "Push Day", notes: "Old notes")
            ]
        )
        let viewModel = WorkoutTemplateEditViewModel(
            summary: WorkoutTemplateSummary(id: 500, title: "Push Day", exerciseCount: 3, setCount: 9),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        viewModel.title = "Upper Push"
        viewModel.notes = "Updated notes"

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(dataManager.updatedRoutine?.id, 500)
        XCTAssertEqual(dataManager.updatedRoutine?.name, "Upper Push")
        XCTAssertEqual(dataManager.updatedRoutine?.notes, "Updated notes")
        XCTAssertEqual(dataManager.createWorkoutSessionCallCount, 0)
        XCTAssertEqual(dataManager.createWorkoutSetCallCount, 0)
    }

    func testLoadPopulatesFieldsFromStoredRoutine() async {
        let dataManager = FakeWorkoutTemplateEditDataManager(
            routineByID: [
                600: Routine(id: 600, name: "Leg Day", notes: "Heavy day")
            ]
        )
        let viewModel = WorkoutTemplateEditViewModel(
            summary: WorkoutTemplateSummary(id: 600, title: "Leg Day", exerciseCount: 4, setCount: 12),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.title, "Leg Day")
        XCTAssertEqual(viewModel.notes, "Heavy day")
        XCTAssertNil(viewModel.errorMessage)
    }
}

private final class FakeWorkoutTemplateEditDataManager: FitnessTemplateDataManaging {
    var routineByID: [Int64: Routine]
    var updatedRoutine: Routine?
    var createWorkoutSessionCallCount = 0
    var createWorkoutSetCallCount = 0

    init(routineByID: [Int64: Routine]) {
        self.routineByID = routineByID
    }

    func fetchRoutine(by id: Int64) async throws -> Routine? {
        routineByID[id]
    }

    func fetchAllRoutines() async throws -> [Routine] {
        Array(routineByID.values)
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        []
    }

    func updateRoutine(_ routine: Routine) async throws -> Routine {
        updatedRoutine = routine
        routineByID[routine.id ?? 0] = routine
        return routine
    }
}
