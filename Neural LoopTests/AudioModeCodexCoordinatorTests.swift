import XCTest
import CodexCore
@testable import Neural_Loop

@MainActor
final class AudioModeCodexCoordinatorTests: XCTestCase {
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
        XCTAssertTrue(model.savedFleetingNotes.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created: Buy milk")
        XCTAssertFalse(coordinator.isSending)
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
    private(set) var savedFleetingNotes: [CreateFleetingNoteRequest] = []
    private let fleetingNoteSaveResult: FleetingNote?

    init(
        llmEnabled: Bool,
        fleetingNoteSaveResult: FleetingNote? = FleetingNote(
            id: 1,
            created_at: ISO8601DateFormatter().date(from: "2026-04-15T09:30:00Z")!,
            note: "Remember the keys"
        ),
        codexAccessToken: String? = "token",
        codexAccountID: String? = "account"
    ) {
        self.llm_enabled = llmEnabled
        self.fleetingNoteSaveResult = fleetingNoteSaveResult
        self.codexAccessToken = codexAccessToken
        self.codexAccountID = codexAccountID
    }

    func saveTask(_ task: Tasks) async -> Tasks? {
        savedTasks.append(task)
        return task
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
