import XCTest
import CodexCore
@testable import Neural_Loop

@MainActor
final class AudioModeCodexCoordinatorTests: XCTestCase {
    private let iso8601Formatter = ISO8601DateFormatter()

    func testClarificationResponseIsShownInFeed() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .clarify(text: "Which task should I create?"),
            returnedState: CodexConversationState(previousResponseID: "resp_1")
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Create something")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .assistant])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Which task should I create?")
        XCTAssertEqual(coordinator.codexState.previousResponseID, "resp_1")
        XCTAssertFalse(coordinator.isSending)
        XCTAssertNil(coordinator.errorMessage)
    }

    func testCreateTaskToolCallPersistsTaskAndShowsConfirmation() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Buy milk",
                    "description": "From the store"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Buy milk")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedTasks.first?.title, "Buy milk")
        XCTAssertEqual(model.savedTasks.first?.description, "From the store")
        XCTAssertNil(model.savedTasks.first?.start_date)
        XCTAssertNil(model.savedTasks.first?.duration)
        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created: Buy milk")
        XCTAssertFalse(coordinator.isSending)
    }

    func testCreateSubTaskToolCallPersistsSubTaskAndShowsConfirmation() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_sub_task",
                arguments: [
                    "task_id": 42,
                    "title": "  Draft outline  "
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Add a subtask")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedSubTasks.count, 1)
        XCTAssertEqual(model.savedSubTasks.first?.task_id, 42)
        XCTAssertEqual(model.savedSubTasks.first?.title, "Draft outline")
        XCTAssertFalse(model.savedTasks.contains { $0.title == "Draft outline" })
        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Subtask created under task 42: Draft outline")
        XCTAssertFalse(coordinator.isSending)
        XCTAssertNil(coordinator.errorMessage)
    }

    func testCreateSubTaskToolCallRejectsOutOfRangeParentTaskID() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_sub_task",
                arguments: [
                    "task_id": 1e100,
                    "title": "Draft outline"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Add a subtask")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex did not provide a parent task id.")
    }

    func testCreateTaskToolCallPersistsScheduledTaskWithExplicitTimeAndDefaultDuration() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Join standup",
                    "description": "Team sync at the office",
                    "start_date": "2026-04-16T09:30:00Z"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Join standup tomorrow at 9:30")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedTasks.first?.title, "Join standup")
        XCTAssertEqual(model.savedTasks.first?.start_date, iso8601Formatter.date(from: "2026-04-16T09:30:00Z"))
        XCTAssertEqual(model.savedTasks.first?.duration, 900)
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created: Join standup")
    }

    func testCreateTaskToolCallParsesTimezoneLessStartDateInLocalTimezone() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Join standup",
                    "start_date": "2026-04-16T09:30:00"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Join standup tomorrow at 9:30")
        await Task.yield()
        await Task.yield()

        guard let savedStartDate = model.savedTasks.first?.start_date else {
            return XCTFail("Expected saved task start date")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: savedStartDate)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 16)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 0)
        XCTAssertEqual(model.savedTasks.first?.duration, 900)
    }

    func testCreateTaskToolCallDefaultsDateOnlyScheduleToAfternoon() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Call dentist",
                    "description": "Scheduled for the afternoon by default",
                    "start_date": "2026-04-20"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Call dentist on April 20")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.savedTasks.count, 1)
        guard let savedTask = model.savedTasks.first else {
            return XCTFail("Expected saved task")
        }
        XCTAssertEqual(savedTask.duration, 900)

        let calendar = Calendar.current
        let startDate = savedTask.start_date ?? .distantPast
        XCTAssertEqual(calendar.component(.year, from: startDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: startDate), 4)
        XCTAssertEqual(calendar.component(.day, from: startDate), 20)
        XCTAssertEqual(calendar.component(.hour, from: startDate), 12)
        XCTAssertEqual(calendar.component(.minute, from: startDate), 0)
    }

    func testCreateTaskToolCallPreservesExplicitDurationWhenProvided() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Deep work",
                    "start_date": "2026-04-18T13:00:00Z",
                    "duration": 1800
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Schedule deep work Saturday at 1 PM for 30 minutes")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedTasks.first?.duration, 1800)
    }

    func testCreateTaskToolCallRejectsInvalidStartDate() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Plan trip",
                    "start_date": "next blursday"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Plan trip next blursday")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex provided an invalid task start date: next blursday")
    }

    func testCreateSubTaskToolCallRejectsBlankTitle() async {
        let parentTask = Tasks(
            id: 42,
            title: "Parent task",
            description: nil,
            priority: 0,
            goal_id: nil,
            lifearea_id: nil,
            is_completed: false,
            is_deadline: false,
            completed_at: nil,
            recursion_rule: nil,
            start_date: nil,
            duration: nil,
            created_at: nil,
            updated_at: nil
        )
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            seededTasks: [parentTask]
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_sub_task",
                arguments: [
                    "task_id": 42,
                    "title": "   "
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Add a subtask")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex did not provide a subtask title.")
    }

    func testCreateSubTaskToolCallRejectsMissingParentTaskContext() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_sub_task",
                arguments: [
                    "title": "Draft outline"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Add a subtask")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex did not provide a parent task id.")
    }

    func testCreateSubTaskToolCallShowsFailureWhenPersistenceFails() async {
        let parentTask = Tasks(
            id: 42,
            title: "Parent task",
            description: nil,
            priority: 0,
            goal_id: nil,
            lifearea_id: nil,
            is_completed: false,
            is_deadline: false,
            completed_at: nil,
            recursion_rule: nil,
            start_date: nil,
            duration: nil,
            created_at: nil,
            updated_at: nil
        )
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            seededTasks: [parentTask],
            subTaskSaveShouldFail: true
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_sub_task",
                arguments: [
                    "task_id": 42,
                    "title": "Draft outline"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Add a subtask")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedSubTasks.count, 1)
        XCTAssertTrue(coordinator.conversationFeed.map(\.role).contains(.error))
        XCTAssertEqual(coordinator.errorMessage, "Subtask could not be saved.")
    }

    func testFollowupTurnReusesCodexHistoryAndResponseState() async throws {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient { messages, state, callCount in
            switch callCount {
            case 1:
                XCTAssertEqual(messages.count, 1)
                XCTAssertEqual(messages.first?.role, "user")
                XCTAssertEqual(messages.first?.content.first?.text, "Create a task")
                XCTAssertNil(state.previousResponseID)
                return CodexIntentResult(
                    action: .clarify(text: "What should the task be called?"),
                    state: CodexConversationState(previousResponseID: "resp_1")
                )
            case 2:
                XCTAssertEqual(state.previousResponseID, "resp_1")
                XCTAssertEqual(messages.map(\.role), ["user", "assistant", "user"])
                XCTAssertEqual(messages[0].content.first?.text, "Create a task")
                XCTAssertEqual(messages[1].content.first?.text, "What should the task be called?")
                XCTAssertEqual(messages[2].content.first?.text, "Buy milk")
                return CodexIntentResult(
                    action: .clarify(text: "Should I add a description too?"),
                    state: CodexConversationState(previousResponseID: "resp_2")
                )
            default:
                XCTFail("Unexpected call count \(callCount)")
                return CodexIntentResult(
                    action: .clarify(text: "Unexpected"),
                    state: state
                )
            }
        }
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Create a task")
        await Task.yield()
        await Task.yield()

        coordinator.handleCommittedTranscript("Buy milk")
        await Task.yield()
        await Task.yield()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 2)
        XCTAssertEqual(coordinator.codexState.previousResponseID, "resp_2")
        XCTAssertEqual(
            coordinator.conversationFeed.map(\.role),
            [.user, .status, .assistant, .user, .status, .assistant]
        )
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Should I add a description too?")
    }

    func testNotesToolCallPersistsFleetingNoteAndShowsConfirmation() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "Remember the keys"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Remember the keys")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertEqual(model.savedFleetingNotes.map(\.note), ["Remember the keys"])
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Fleeting note created: Remember the keys")
    }

    func testNotesToolCallRejectsBlankContent() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "   "
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Save a note")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex did not provide note content.")
    }

    func testNotesToolCallFallsBackToNoteWhenContentIsBlank() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "   ",
                    "note": "Remember the passport"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Remember the passport")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertEqual(model.savedFleetingNotes.map(\.note), ["Remember the passport"])
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Fleeting note created: Remember the passport")
    }

    func testNotesToolCallShowsFailureWhenPersistenceFails() async {
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            fleetingNoteSaveResult: nil
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "note": "Remember the passport"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Remember the passport")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertEqual(model.savedFleetingNotes.map(\.note), ["Remember the passport"])
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Fleeting note could not be saved.")
    }

    func testDisabledLLMBlocksCodexRequestAndSurfacesStatus() async {
        let model = FakeAudioModeCodexModel(llmEnabled: false)
        let client = FakeAudioModeCodexClient(result: .clarify(text: "Unused"))
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a task")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 0)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status])
        XCTAssertEqual(coordinator.statusMessage, "LLM access is disabled.")
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isSending)
        XCTAssertEqual(coordinator.bannerText, "LLM access is disabled.")
        XCTAssertEqual(coordinator.bannerTone, .warning)
        XCTAssertTrue(coordinator.isLLMDisabled)
    }

    func testCodexFailureSurfacesErrorWithoutCrashing() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(error: TestError.codexFailure)
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Break")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, TestError.codexFailure.localizedDescription)
        XCTAssertFalse(coordinator.isSending)
        XCTAssertEqual(coordinator.bannerText, TestError.codexFailure.localizedDescription)
        XCTAssertEqual(coordinator.bannerTone, .error)
    }

    func testCancelledDrainDoesNotAppendErrorAfterReset() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(result: .cancelledAfterYield(error: TestError.codexFailure))
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Cancel me")
        await Task.yield()
        coordinator.resetConversation()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(coordinator.conversationFeed.isEmpty)
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isSending)
    }
}

private enum TestError: LocalizedError {
    case codexFailure

    var errorDescription: String? {
        switch self {
        case .codexFailure:
            return "Codex failure"
        }
    }
}

private final class FakeAudioModeCodexModel: AudioModeCodexModel {
    var llm_enabled: Bool
    var codexAccessToken: String?
    var codexAccountID: String?
    private(set) var savedTasks: [Tasks] = []
    private(set) var savedSubTasks: [SubTasks] = []
    private(set) var savedFleetingNotes: [CreateFleetingNoteRequest] = []
    private let seededTasks: [Tasks]
    private let fleetingNoteSaveResult: FleetingNote?
    private let subTaskSaveShouldFail: Bool
    private let subTaskSaveResult: SubTasks?

    init(
        llmEnabled: Bool,
        seededTasks: [Tasks] = [],
        subTaskSaveShouldFail: Bool = false,
        subTaskSaveResult: SubTasks? = nil,
        fleetingNoteSaveResult: FleetingNote? = FleetingNote(
            id: 1,
            created_at: ISO8601DateFormatter().date(from: "2026-04-15T09:30:00Z")!,
            note: "Remember the keys"
        ),
        codexAccessToken: String? = "token",
        codexAccountID: String? = "account"
    ) {
        self.llm_enabled = llmEnabled
        self.seededTasks = seededTasks
        self.subTaskSaveShouldFail = subTaskSaveShouldFail
        self.subTaskSaveResult = subTaskSaveResult
        self.fleetingNoteSaveResult = fleetingNoteSaveResult
        self.codexAccessToken = codexAccessToken
        self.codexAccountID = codexAccountID
    }

    func getTask(by id: Int64) -> Tasks? {
        if let savedTask = savedTasks.first(where: { $0.id == id }) {
            return savedTask
        }

        return seededTasks.first(where: { $0.id == id })
    }

    func saveTask(_ task: Tasks) async -> Tasks? {
        savedTasks.append(task)
        return task
    }

    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks? {
        let request = SubTasks(
            id: UUID(),
            task_id: taskId,
            title: title,
            is_completed: false
        )
        savedSubTasks.append(request)

        if subTaskSaveShouldFail {
            return nil
        }

        if let subTaskSaveResult {
            return SubTasks(
                id: subTaskSaveResult.id,
                task_id: taskId,
                title: title,
                is_completed: subTaskSaveResult.is_completed
            )
        }

        return request
    }

    func saveFleetingNote(_ request: CreateFleetingNoteRequest) async -> FleetingNote? {
        savedFleetingNotes.append(request)

        guard let fleetingNoteSaveResult else {
            return nil
        }

        return FleetingNote(
            id: fleetingNoteSaveResult.id,
            created_at: fleetingNoteSaveResult.created_at,
            note: request.note
        )
    }
}

private final class FakeAudioModeCodexClient: AudioModeCodexExecuting {
    enum Outcome {
        case clarify(text: String)
        case callTool(name: String, arguments: [String: Any])
        case cancelledAfterYield(error: Error)
    }

    typealias Handler = (_ messages: [CodexInputMessage], _ state: CodexConversationState, _ callCount: Int) async throws -> CodexIntentResult

    private let handler: Handler
    private(set) var converseCallCount = 0
    private(set) var capturedMessages: [[CodexInputMessage]] = []
    private(set) var capturedStates: [CodexConversationState] = []

    init(
        result: Outcome,
        returnedState: CodexConversationState = CodexConversationState()
    ) {
        self.handler = { _, _, _ in
            switch result {
            case .clarify(let text):
                return CodexIntentResult(
                    action: .clarify(text: text),
                    state: returnedState
                )
            case .callTool(let name, let arguments):
                return CodexIntentResult(
                    action: .callTool(name: name, arguments: arguments),
                    state: returnedState
                )
            case .cancelledAfterYield(let error):
                await Task.yield()
                if Task.isCancelled {
                    throw error
                }

                return CodexIntentResult(
                    action: .clarify(text: "Unused"),
                    state: returnedState
                )
            }
        }
    }

    init(error: Error) {
        self.handler = { _, _, _ in
            throw error
        }
    }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        converseCallCount += 1
        capturedMessages.append(messages)
        capturedStates.append(state)
        return try await handler(messages, state, converseCallCount)
    }
}
