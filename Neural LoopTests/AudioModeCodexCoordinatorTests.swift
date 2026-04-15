import XCTest
@testable import Neural_Loop

@MainActor
final class AudioModeCodexCoordinatorTests: XCTestCase {
    func testClarificationResponseIsShownInFeed() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(result: .clarify(text: "Which task should I create?"))
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Create something")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.executeIntentCallCount, 1)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .assistant])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Which task should I create?")
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

        XCTAssertEqual(client.executeIntentCallCount, 1)
        XCTAssertEqual(model.savedTasks.count, 1)
        XCTAssertEqual(model.savedTasks.first?.title, "Buy milk")
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Task created: Buy milk")
        XCTAssertFalse(coordinator.isSending)
    }

    func testNotesToolCallShowsDummyConfirmation() async {
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

        XCTAssertEqual(client.executeIntentCallCount, 1)
        XCTAssertTrue(model.savedTasks.isEmpty)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .toolResult])
        XCTAssertEqual(coordinator.conversationFeed.last?.content, "Fleeting notes is created.")
    }

    func testDisabledLLMBlocksCodexRequestAndSurfacesStatus() async {
        let model = FakeAudioModeCodexModel(llmEnabled: false)
        let client = FakeAudioModeCodexClient(result: .clarify(text: "Unused"))
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Make a task")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.executeIntentCallCount, 0)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status])
        XCTAssertEqual(coordinator.statusMessage, "LLM access is disabled.")
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isSending)
    }

    func testCodexFailureSurfacesErrorWithoutCrashing() async {
        let model = FakeAudioModeCodexModel(llmEnabled: true)
        let client = FakeAudioModeCodexClient(error: TestError.codexFailure)
        let coordinator = AudioModeCodexCoordinator(model: model, codexClient: client)

        coordinator.handleCommittedTranscript("Break")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(client.executeIntentCallCount, 1)
        XCTAssertEqual(coordinator.conversationFeed.map(\.role), [.user, .status, .error])
        XCTAssertEqual(coordinator.errorMessage, TestError.codexFailure.localizedDescription)
        XCTAssertFalse(coordinator.isSending)
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

        XCTAssertEqual(client.executeIntentCallCount, 1)
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

    init(
        llmEnabled: Bool,
        codexAccessToken: String? = "token",
        codexAccountID: String? = "account"
    ) {
        self.llm_enabled = llmEnabled
        self.codexAccessToken = codexAccessToken
        self.codexAccountID = codexAccountID
    }

    func saveTask(_ task: Tasks) async -> Tasks? {
        savedTasks.append(task)
        return task
    }
}

private final class FakeAudioModeCodexClient: AudioModeCodexExecuting {
    enum Outcome {
        case clarify(text: String)
        case callTool(name: String, arguments: [String: Any])
        case cancelledAfterYield(error: Error)
    }

    private let outcome: Outcome?
    private let error: Error?
    private(set) var executeIntentCallCount = 0

    init(result: Outcome) {
        self.outcome = result
        self.error = nil
    }

    init(error: Error) {
        self.outcome = nil
        self.error = error
    }

    func executeIntent(_ prompt: String) async throws -> CodexAction {
        executeIntentCallCount += 1

        if let error {
            throw error
        }

        guard let outcome else {
            throw TestError.codexFailure
        }

        switch outcome {
        case .clarify(let text):
            return .clarify(text: text)
        case .callTool(let name, let arguments):
            return .callTool(name: name, arguments: arguments)
        case .cancelledAfterYield(let error):
            await Task.yield()
            if Task.isCancelled {
                throw error
            }

            return .clarify(text: "Unused")
        }
    }
}
