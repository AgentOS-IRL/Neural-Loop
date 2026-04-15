import Foundation
import Combine

protocol AudioModeCodexExecuting {
    func executeIntent(_ prompt: String) async throws -> CodexAction
}

protocol AudioModeCodexModel: AnyObject {
    var llm_enabled: Bool { get }
    var codexAccessToken: String? { get }
    var codexAccountID: String? { get }
    func saveTask(_ task: Tasks) async -> Tasks?
}

@MainActor
final class AudioModeCodexCoordinator: ObservableObject {
    @Published private(set) var conversationFeed: [AudioTranscriptMessage] = []
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    private let model: any AudioModeCodexModel
    private let codexClient: (any AudioModeCodexExecuting)?
    private var pendingTranscripts: [String] = []
    private var drainTask: Task<Void, Never>?

    init(
        model: any AudioModeCodexModel,
        codexClient: (any AudioModeCodexExecuting)? = nil
    ) {
        self.model = model
        self.codexClient = codexClient
    }

    func resetConversation() {
        drainTask?.cancel()
        drainTask = nil
        pendingTranscripts.removeAll()
        conversationFeed.removeAll()
        isSending = false
        errorMessage = nil
        statusMessage = nil
    }

    func handleCommittedTranscript(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return
        }

        errorMessage = nil
        conversationFeed.append(.init(role: .user, content: trimmedTranscript))
        pendingTranscripts.append(trimmedTranscript)
        startDrainIfNeeded()
    }

    private func startDrainIfNeeded() {
        guard drainTask == nil else {
            return
        }

        drainTask = Task { @MainActor [weak self] in
            await self?.drainPendingTranscripts()
        }
    }

    private func drainPendingTranscripts() async {
        defer {
            drainTask = nil
        }

        while !pendingTranscripts.isEmpty {
            if Task.isCancelled {
                return
            }

            let transcript = pendingTranscripts.removeFirst()
            await processTranscript(transcript)
        }
    }

    private func processTranscript(_ transcript: String) async {
        guard model.llm_enabled else {
            appendStatus("LLM access is disabled.")
            return
        }

        guard let client = resolvedCodexClient() else {
            appendError("Codex client is unavailable.")
            return
        }

        isSending = true
        appendStatus("Sending to Codex...")

        defer {
            isSending = false
            if statusMessage == "Sending to Codex..." {
                statusMessage = nil
            }
        }

        do {
            let action = try await client.executeIntent(transcript)

            if Task.isCancelled {
                return
            }

            try await handle(action)
        } catch is CancellationError {
            return
        } catch {
            appendError(error.localizedDescription)
        }
    }

    private func handle(_ action: CodexAction) async throws {
        switch action {
        case .clarify(let text):
            appendAssistant(text)
        case .callTool(let name, let arguments):
            try await handleToolCall(name: name, arguments: arguments)
        }
    }

    private func handleToolCall(name: String, arguments: [String: Any]) async throws {
        switch normalizedToolName(name) {
        case "create_task":
            try await handleCreateTask(arguments: arguments)
        case "notes":
            appendToolResult("Fleeting notes is created.")
        default:
            appendError("Unknown Codex tool call: \(name)")
        }
    }

    private func handleCreateTask(arguments: [String: Any]) async throws {
        guard let title = stringValue(for: ["title"], in: arguments) else {
            appendError("Codex did not provide a task title.")
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            appendError("Codex did not provide a task title.")
            return
        }

        let description = optionalStringValue(for: ["description", "content"], in: arguments)
        let task = Tasks(
            id: nil,
            title: trimmedTitle,
            description: description,
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

        guard let savedTask = await model.saveTask(task) else {
            appendError("Task could not be saved.")
            return
        }

        appendToolResult("Task created: \(savedTask.title)")
    }

    private func resolvedCodexClient() -> (any AudioModeCodexExecuting)? {
        if let codexClient {
            return codexClient
        }

        guard
            let accessToken = model.codexAccessToken,
            let accountID = model.codexAccountID
        else {
            return nil
        }

        return CodexStructuredToolAudioModeAdapter(
            tool: CodexStructuredTool(access_token: accessToken, account_id: accountID)
        )
    }

    private func appendAssistant(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        conversationFeed.append(.init(role: .assistant, content: trimmed))
    }

    private func appendToolResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        conversationFeed.append(.init(role: .toolResult, content: trimmed))
    }

    private func appendStatus(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        conversationFeed.append(.init(role: .status, content: trimmed))
        statusMessage = trimmed
    }

    private func appendError(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        errorMessage = trimmed
        statusMessage = nil
        conversationFeed.append(.init(role: .error, content: trimmed))
    }

    private func normalizedToolName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func stringValue(for keys: [String], in arguments: [String: Any]) -> String? {
        for key in keys {
            if let value = arguments[key] as? String {
                return value
            }
        }
        return nil
    }

    private func optionalStringValue(for keys: [String], in arguments: [String: Any]) -> String? {
        stringValue(for: keys, in: arguments)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class CodexStructuredToolAudioModeAdapter: AudioModeCodexExecuting {
    private let tool: CodexStructuredTool

    init(tool: CodexStructuredTool) {
        self.tool = tool
    }

    func executeIntent(_ prompt: String) async throws -> CodexAction {
        try await tool.executeIntent(prompt)
    }
}
