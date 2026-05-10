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

    func testDefaultIntentToolsExcludeCreateSubTask() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let coordinator = AudioModeCodexCoordinator(model: model)

        XCTAssertEqual(coordinator.intentTools.map(\.name), ["create_task", "create_shopping_list", "Notes"])
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
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created (id: 101): Buy milk.")
        XCTAssertFalse(coordinator.isSending)
    }

    func testCreateTaskToolCallPersistsTaskThenNestedSubTasksInOrder() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Grocery list",
                    "description": "Weekly shopping",
                    "sub_tasks": [
                        ["title": "  Milk  "],
                        ["title": "Eggs"],
                        ["title": "Bread"]
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a grocery list with milk, eggs, and bread")
        await Task.yield()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedSubTasks.count, 3)
        XCTAssertEqual(model.savedSubTasks.compactMap(\.task_id), [101, 101, 101])
        XCTAssertEqual(model.savedSubTasks.map(\.title), ["Milk", "Eggs", "Bread"])
        XCTAssertEqual(
            model.saveEvents,
            [
                .task(title: "Grocery list", id: 101),
                .subTask(title: "Milk", taskId: 101),
                .subTask(title: "Eggs", taskId: 101),
                .subTask(title: "Bread", taskId: 101)
            ]
        )
        XCTAssertEqual(
            coordinator.conversationFeed.last?.content,
            "Task created (id: 101): Grocery list. Subtasks created: Milk, Eggs, Bread."
        )
        XCTAssertFalse(coordinator.isSending)
        XCTAssertNil(coordinator.errorMessage)
    }

    func testCreateTaskToolCallIgnoresBlankNestedSubTaskTitles() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Todo list",
                    "sub_tasks": [
                        ["title": "   "],
                        ["title": "Call dentist"],
                        ["title": ""]
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a todo list")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedSubTasks.count, 1)
        XCTAssertEqual(model.savedSubTasks.first?.title, "Call dentist")
        XCTAssertEqual(model.saveEvents, [.task(title: "Todo list", id: 101), .subTask(title: "Call dentist", taskId: 101)])
        XCTAssertEqual(
            coordinator.conversationFeed.last?.content,
            "Task created (id: 101): Todo list. Subtasks created: Call dentist."
        )
        XCTAssertNil(coordinator.errorMessage)
    }

    func testShoppingListToolCallPersistsTemplatedTaskAndItems() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_shopping_list",
                arguments: [
                    "location": "Tesco",
                    "items": [
                        "  Milk  ",
                        "Eggs"
                    ],
                    "start_date": "2026-04-20"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a Tesco shopping list with milk and eggs")
        await Task.yield()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedTasks.first?.title, "Shopping list: Tesco")
        XCTAssertEqual(model.savedTasks.first?.description, "Shopping list for Tesco. Items: Milk, Eggs.")
        XCTAssertEqual(model.savedTasks.first?.duration, 900)
        XCTAssertEqual(model.savedSubTasks.map(\.title), ["Milk", "Eggs"])
        XCTAssertEqual(model.savedSubTasks.compactMap(\.task_id), [101, 101])

        let calendar = Calendar.current
        let startDate = model.savedTasks.first?.start_date ?? .distantPast
        XCTAssertEqual(calendar.component(.year, from: startDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: startDate), 4)
        XCTAssertEqual(calendar.component(.day, from: startDate), 20)
        XCTAssertEqual(calendar.component(.hour, from: startDate), 15)
        XCTAssertEqual(calendar.component(.minute, from: startDate), 0)
        XCTAssertEqual(
            coordinator.conversationFeed.last?.content,
            "Shopping list created (id: 101): Shopping list: Tesco. Subtasks created: Milk, Eggs."
        )
        XCTAssertNil(coordinator.errorMessage)
    }

    func testShoppingListToolCallDefaultsScheduleToTodayAtAfternoon() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_shopping_list",
                arguments: [
                    "location": "Tesco",
                    "items": [
                        "Apples"
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)
        let now = Date()

        coordinator.handleCommittedTranscript("Add apples to a shopping list")
        await Task.yield()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedTasks.first?.title, "Shopping list: Tesco")
        XCTAssertEqual(model.savedTasks.first?.description, "Shopping list for Tesco. Items: Apples.")
        XCTAssertEqual(model.savedSubTasks.map(\.title), ["Apples"])

        let calendar = Calendar.current
        let startDate = model.savedTasks.first?.start_date ?? .distantPast
        XCTAssertEqual(calendar.component(.year, from: startDate), calendar.component(.year, from: now))
        XCTAssertEqual(calendar.component(.month, from: startDate), calendar.component(.month, from: now))
        XCTAssertEqual(calendar.component(.day, from: startDate), calendar.component(.day, from: now))
        XCTAssertEqual(calendar.component(.hour, from: startDate), 15)
        XCTAssertEqual(calendar.component(.minute, from: startDate), 0)
    }

    func testShoppingListToolCallRejectsMissingLocation() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_shopping_list",
                arguments: [
                    "items": [
                        "Apples"
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a shopping list with apples")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex did not provide a shopping list location.")
    }

    func testShoppingListToolCallRejectsMissingItems() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_shopping_list",
                arguments: [
                    "location": "Tesco",
                    "items": []
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a Tesco shopping list")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Codex did not provide shopping list items.")
    }

    func testCreateTaskToolCallShowsFailureWhenParentSaveFails() async {
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            taskSaveShouldFail: true
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Broken task",
                    "sub_tasks": [
                        ["title": "Should not save"]
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Create a broken task")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, "Task could not be saved.")
    }

    func testCreateTaskToolCallReportsPartialSuccessWhenNestedSubTaskSaveFails() async {
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            subTaskSaveShouldFail: true
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Grocery list",
                    "sub_tasks": [
                        ["title": "Milk"],
                        ["title": "Eggs"],
                        ["title": "Bread"]
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Create a grocery list")
        await Task.yield()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedSubTasks.count, 3)
        XCTAssertEqual(
            coordinator.conversationFeed.last?.content,
            "Task created (id: 101): Grocery list. Subtasks not created: Milk, Eggs, Bread."
        )
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isSending)
    }

    func testCreateTaskToolCallReportsUnknownIdWhenSaveDoesNotReturnOne() async {
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            taskSaveResultID: 0
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Loose task",
                    "sub_tasks": [
                        ["title": "Should not save"]
                    ]
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Create a task without an id")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created (id: unknown): Loose task. Subtasks not created: Should not save.")
        XCTAssertNil(coordinator.errorMessage)
    }

    func testCreateSubTaskToolCallIsRejectedAsUnknownTool() async {
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
        XCTAssertTrue(model.savedSubTasks.isEmpty)
        XCTAssertFalse(model.savedTasks.contains { $0.title == "Draft outline" })
        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertFalse(coordinator.isSending)
        XCTAssertEqual(coordinator.errorMessage, "Unknown Codex tool call: create_sub_task")
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
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created (id: 101): Join standup.")
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
        XCTAssertEqual(calendar.component(.hour, from: startDate), 15)
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
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Personal note created (id: 1): Remember the keys")
        XCTAssertEqual(coordinator.conversationFeed.last?.toolResultKind, .personalNoteCreated)
        XCTAssertEqual(coordinator.viewData.noteTargetStatusText, "Notes: Personal")
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
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Personal note created (id: 1): Remember the passport")
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
        XCTAssertEqual(coordinator.errorMessage, "Personal note could not be saved.")
    }

    func testNotesToolCallWithPersonalSourcePersistsPersonalNote() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "Remember the passport",
                    "source": "personal"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Save a personal note")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.savedFleetingNotes.map(\.note), ["Remember the passport"])
        XCTAssertTrue(model.savedWorkReminders.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Personal note created (id: 1): Remember the passport")
    }

    func testNotesToolCallWithScopePersonalPersistsPersonalNote() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "Remember the passport",
                    "scope": "personal"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Save a note")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.savedFleetingNotes.map(\.note), ["Remember the passport"])
        XCTAssertTrue(model.savedWorkReminders.isEmpty)
    }

    func testNotesToolCallWithWorkSourceCreatesWorkReminder() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "Follow up with customer",
                    "source": "work"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Save a work note")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(model.savedWorkReminders.map(\.title), ["Follow up with customer"])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Work note created: Follow up with customer")
        XCTAssertEqual(coordinator.conversationFeed.last?.toolResultKind, .workNoteCreated)
        XCTAssertEqual(coordinator.viewData.noteTargetStatusText, "Notes: Work")
    }

    func testNotesToolCallWithWorkSourceSurfacesPermissionFailure() async {
        let model = FakeAudioModeCodexModel(
            llmEnabled: true,
            workReminderError: GenesysReminderServiceError.accessDenied
        )
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "Follow up with customer",
                    "source": "work"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Save a work note")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(model.savedWorkReminders.map(\.title), ["Follow up with customer"])
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, GenesysReminderServiceError.accessDenied.localizedDescription)
        XCTAssertEqual(coordinator.viewData.noteTargetStatusText, "Notes: Work")
    }

    func testNotesToolCallWithUnknownSourceShowsError() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(
            result: .callTool(
                name: "Notes",
                arguments: [
                    "content": "Remember the passport",
                    "source": "team"
                ]
            )
        )
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Save a note")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertTrue(model.savedWorkReminders.isEmpty)
        XCTAssertEqual(coordinator.errorMessage, "Codex provided an unknown note source.")
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
    private(set) var savedWorkReminders: [CreateWorkReminderRequest] = []
    private let seededTasks: [Tasks]
    private let fleetingNoteSaveResult: FleetingNote?
    private let workReminderSaveResult: WorkReminder?
    private let workReminderError: Error?
    private let taskSaveShouldFail: Bool
    private let subTaskSaveShouldFail: Bool
    private let subTaskSaveResult: SubTasks?
    private let taskSaveResultID: Int64
    private let subTaskSaveResultID: UUID
    private(set) var saveEvents: [SaveEvent] = []

    enum SaveEvent: Equatable {
        case task(title: String, id: Int64)
        case subTask(title: String, taskId: Int64)
    }

    init(
        llmEnabled: Bool,
        seededTasks: [Tasks] = [],
        taskSaveShouldFail: Bool = false,
        subTaskSaveShouldFail: Bool = false,
        subTaskSaveResult: SubTasks? = nil,
        fleetingNoteSaveResult: FleetingNote? = FleetingNote(
            id: 1,
            created_at: ISO8601DateFormatter().date(from: "2026-04-15T09:30:00Z")!,
            note: "Remember the keys"
        ),
        workReminderSaveResult: WorkReminder? = WorkReminder(
            id: "work-1",
            title: "Follow up with customer",
            notes: nil,
            createdAt: ISO8601DateFormatter().date(from: "2026-04-15T09:30:00Z")!,
            dueDate: nil,
            calendarTitle: "Reminders",
            sourceTitle: "Genesys"
        ),
        workReminderError: Error? = nil,
        taskSaveResultID: Int64 = 101,
        subTaskSaveResultID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
        codexAccessToken: String? = "token",
        codexAccountID: String? = "account"
    ) {
        self.llm_enabled = llmEnabled
        self.seededTasks = seededTasks
        self.taskSaveShouldFail = taskSaveShouldFail
        self.subTaskSaveShouldFail = subTaskSaveShouldFail
        self.subTaskSaveResult = subTaskSaveResult
        self.fleetingNoteSaveResult = fleetingNoteSaveResult
        self.workReminderSaveResult = workReminderSaveResult
        self.workReminderError = workReminderError
        self.taskSaveResultID = taskSaveResultID
        self.subTaskSaveResultID = subTaskSaveResultID
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
        guard !taskSaveShouldFail else {
            return nil
        }

        let savedTask = Tasks(
            id: task.id ?? taskSaveResultID,
            title: task.title,
            description: task.description,
            priority: task.priority,
            goal_id: task.goal_id,
            lifearea_id: task.lifearea_id,
            is_completed: task.is_completed,
            is_deadline: task.is_deadline,
            completed_at: task.completed_at,
            recursion_rule: task.recursion_rule,
            start_date: task.start_date,
            duration: task.duration,
            created_at: task.created_at,
            updated_at: task.updated_at
        )
        savedTasks.append(savedTask)
        saveEvents.append(.task(title: savedTask.title, id: savedTask.id ?? -1))
        return savedTask
    }

    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks? {
        let request = SubTasks(
            id: subTaskSaveResultID,
            task_id: taskId,
            title: title,
            is_completed: false
        )
        savedSubTasks.append(request)
        saveEvents.append(.subTask(title: title, taskId: taskId))

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

    func createWorkReminder(title: String, notes: String?) async throws -> WorkReminder {
        savedWorkReminders.append(CreateWorkReminderRequest(title: title, notes: notes))

        if let workReminderError {
            throw workReminderError
        }

        guard let workReminderSaveResult else {
            throw GenesysReminderServiceError.saveFailed("No fake work reminder result.")
        }

        return WorkReminder(
            id: workReminderSaveResult.id,
            title: title,
            notes: notes,
            createdAt: workReminderSaveResult.createdAt,
            dueDate: workReminderSaveResult.dueDate,
            calendarTitle: workReminderSaveResult.calendarTitle,
            sourceTitle: workReminderSaveResult.sourceTitle
        )
    }

    func validCodexCredentials() async -> CodexCredentials? {
        guard let codexAccessToken,
              let codexAccountID else {
            return nil
        }

        return CodexCredentials(accessToken: codexAccessToken, accountID: codexAccountID)
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
