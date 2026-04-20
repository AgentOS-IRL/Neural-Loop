import XCTest
@testable import Neural_Loop

@MainActor
final class IndividualTodoViewModelTests: XCTestCase {
    func testWhitespaceOnlyTitleIsRejectedByComposer() {
        let viewModel = IndividualTodoViewModel()

        viewModel.newSubTaskTitle = "   \n\t "

        XCTAssertEqual(viewModel.trimmedNewSubTaskTitle, "")
        XCTAssertFalse(viewModel.canAddSubTask)
    }

    func testCreateSubTaskClearsInputOnlyAfterSuccessfulInsert() async {
        let service = MockTodoSubtaskService()
        let expectedSubTask = SubTasks(
            id: UUID(),
            task_id: 42,
            title: "Draft subtask",
            is_completed: false
        )
        service.addResult = expectedSubTask
        service.fetchResults = [[expectedSubTask]]

        let viewModel = IndividualTodoViewModel()
        viewModel.newSubTaskTitle = "  Draft subtask  "

        await viewModel.createSubTask(from: service, taskId: 42)

        XCTAssertEqual(service.addRequests.count, 1)
        XCTAssertEqual(service.addRequests.first?.title, "Draft subtask")
        XCTAssertEqual(viewModel.newSubTaskTitle, "")
        XCTAssertEqual(viewModel.subTasks, [expectedSubTask])
        XCTAssertNil(viewModel.alertMessage)
    }

    func testCreateSubTaskPreservesInputWhenInsertFails() async {
        let service = MockTodoSubtaskService()
        service.addResult = nil

        let viewModel = IndividualTodoViewModel()
        viewModel.newSubTaskTitle = "  Draft subtask  "

        await viewModel.createSubTask(from: service, taskId: 42)

        XCTAssertEqual(service.addRequests.count, 1)
        XCTAssertEqual(viewModel.newSubTaskTitle, "  Draft subtask  ")
        XCTAssertEqual(viewModel.subTasks, [])
        XCTAssertEqual(viewModel.alertMessage, "Unable to add subtask.")
    }

    func testLoadSubTasksRefreshesFromService() async {
        let service = MockTodoSubtaskService()
        let fetchedSubTask = SubTasks(
            id: UUID(),
            task_id: 42,
            title: "Fetched subtask",
            is_completed: false
        )
        service.fetchResults = [[fetchedSubTask]]

        let viewModel = IndividualTodoViewModel()

        await viewModel.loadSubTasks(from: service, taskId: 42)

        XCTAssertEqual(service.fetchRequests, [42])
        XCTAssertEqual(viewModel.subTasks, [fetchedSubTask])
        XCTAssertFalse(viewModel.isLoading)
    }

    func testToggleSubTaskReloadsAfterMutation() async {
        let service = MockTodoSubtaskService()
        let initialSubTask = SubTasks(
            id: UUID(),
            task_id: 42,
            title: "Initial",
            is_completed: false
        )
        let updatedSubTask = SubTasks(
            id: initialSubTask.id,
            task_id: 42,
            title: "Initial",
            is_completed: true
        )
        service.fetchResults = [[initialSubTask], [updatedSubTask]]

        let viewModel = IndividualTodoViewModel()

        await viewModel.loadSubTasks(from: service, taskId: 42)
        await viewModel.toggleSubTask(initialSubTask, from: service, taskId: 42)

        XCTAssertEqual(service.toggleRequests.count, 1)
        XCTAssertEqual(service.toggleRequests.first?.0, initialSubTask.id)
        XCTAssertEqual(service.toggleRequests.first?.1, true)
        XCTAssertEqual(viewModel.subTasks, [updatedSubTask])
    }
}

@MainActor
private final class MockTodoSubtaskService: TodoSubtaskServicing {
    var fetchRequests: [Int64] = []
    var addRequests: [(title: String, taskId: Int64)] = []
    var toggleRequests: [(UUID, Bool)] = []
    var deleteRequests: [UUID] = []

    var fetchResults: [[SubTasks]] = []
    var addResult: SubTasks?

    func getSubTasks(taskId: Int64) async -> [SubTasks] {
        fetchRequests.append(taskId)

        if !fetchResults.isEmpty {
            return fetchResults.removeFirst()
        }

        return []
    }

    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks? {
        addRequests.append((title: title, taskId: taskId))
        return addResult
    }

    func setSubTaskIsCompleted(subtask_id: UUID, is_completed: Bool) async {
        toggleRequests.append((subtask_id, is_completed))
    }

    func deleteSubTask(subtask_id: UUID) async {
        deleteRequests.append(subtask_id)
    }
}
