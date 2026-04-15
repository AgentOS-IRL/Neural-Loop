import Foundation
import Combine
import CodexCore

protocol AudioModeCodexExecuting {
    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult
}

protocol AudioModeCodexModel: AnyObject {
    var llm_enabled: Bool { get }
    var codexAccessToken: String? { get }
    var codexAccountID: String? { get }
    func saveTask(_ task: Tasks) async -> Tasks?
    func saveFleetingNote(_ request: CreateFleetingNoteRequest) async -> FleetingNote?
}

@MainActor
final class AudioModeCodexCoordinator: ObservableObject {
    @Published private(set) var conversationFeed: [AudioTranscriptMessage] = []
    @Published private(set) var codexState = CodexConversationState()
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    private let model: any AudioModeCodexModel
    private let codexClient: (any AudioModeCodexExecuting)?
    private var pendingTranscripts: [String] = []
    private var drainTask: Task<Void, Never>?
    private var codexMessages: [CodexInputMessage] = []

    let intentTools: [CodexTool]
    let intentInstructions: String

    var bannerText: String? {
        if isSending {
            return statusMessage ?? "Sending to Codex..."
        }
        return errorMessage ?? statusMessage
    }

    var bannerTone: AudioModeBannerTone? {
        if errorMessage != nil {
            return .error
        }
        if statusMessage == "LLM access is disabled." {
            return .warning
        }
        if statusMessage != nil {
            return .info
        }
        return nil
    }

    var isLLMDisabled: Bool {
        statusMessage == "LLM access is disabled."
    }

    var viewData: AudioModeConversationViewData {
        AudioModeConversationViewData(
            messages: conversationFeed,
            bannerText: bannerText,
            bannerTone: bannerTone,
            isSending: isSending,
            isLLMDisabled: isLLMDisabled
        )
    }

    init(
        model: any AudioModeCodexModel,
        codexClient: (any AudioModeCodexExecuting)? = nil,
        tools: [CodexTool] = AudioModeCodexCoordinator.defaultIntentTools,
        instructions: String = AudioModeCodexCoordinator.defaultIntentInstructions
    ) {
        self.model = model
        self.codexClient = codexClient
        self.intentTools = tools
        self.intentInstructions = instructions
    }

    func resetConversation() {
        drainTask?.cancel()
        drainTask = nil
        pendingTranscripts.removeAll()
        conversationFeed.removeAll()
        codexMessages.removeAll()
        codexState = CodexConversationState()
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
            let requestMessages = codexMessages + makeCodexMessages(role: .user, content: transcript)
            let result = try await client.converse(
                messages: requestMessages,
                state: codexState,
                tools: intentTools,
                instructions: intentInstructions
            )

            if Task.isCancelled {
                return
            }

            codexMessages = requestMessages
            codexState = result.state
            try await handle(result.action)
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled {
                return
            }

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
            await handleCreateNote(arguments: arguments)
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
        let parsedSchedule = try parseTaskSchedule(arguments: arguments)
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
            start_date: parsedSchedule.startDate,
            duration: parsedSchedule.duration,
            created_at: nil,
            updated_at: nil
        )

        guard let savedTask = await model.saveTask(task) else {
            appendError("Task could not be saved.")
            return
        }

        appendToolResult("Task created: \(savedTask.title)")
    }

    private func parseTaskSchedule(arguments: [String: Any]) throws -> (startDate: Date?, duration: Double?) {
        guard let rawStartDate = optionalStringValue(for: ["start_date"], in: arguments), !rawStartDate.isEmpty else {
            return (nil, nil)
        }

        guard let startDate = parseStartDate(rawStartDate) else {
            throw AudioModeCodexCoordinatorError.invalidTaskStartDate(rawStartDate)
        }

        if let explicitDuration = durationValue(in: arguments) {
            return (startDate, explicitDuration)
        }

        return (startDate, 900)
    }

    private func parseStartDate(_ rawValue: String) -> Date? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        for formatter in Self.iso8601DateFormatters {
            if let date = formatter.date(from: trimmedValue) {
                return date
            }
        }

        guard let dateOnly = Self.dateOnlyFormatter.date(from: trimmedValue) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.dateOnlyFormatter.timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: dateOnly)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12,
            minute: 0,
            second: 0
        ))
    }

    private func durationValue(in arguments: [String: Any]) -> Double? {
        for key in ["duration"] {
            if let value = arguments[key] as? Double {
                return value
            }
            if let value = arguments[key] as? Int {
                return Double(value)
            }
            if let value = arguments[key] as? String {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedValue.isEmpty else {
                    continue
                }

                if let parsedValue = Double(trimmedValue) {
                    return parsedValue
                }
            }
        }

        return nil
    }

    private func handleCreateNote(arguments: [String: Any]) async {
        guard let trimmedNote = firstNonEmptyTrimmedStringValue(for: ["content", "note"], in: arguments) else {
            appendError("Codex did not provide note content.")
            return
        }

        guard !trimmedNote.isEmpty else {
            appendError("Codex did not provide note content.")
            return
        }

        let request = CreateFleetingNoteRequest(note: trimmedNote)
        guard let savedNote = await model.saveFleetingNote(request) else {
            appendError("Fleeting note could not be saved.")
            return
        }

        appendToolResult("Fleeting note created: \(savedNote.note)")
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
        codexMessages.append(contentsOf: makeCodexMessages(role: .assistant, content: trimmed))
    }

    private func appendToolResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        conversationFeed.append(.init(role: .toolResult, content: trimmed))
        codexMessages.append(contentsOf: makeCodexMessages(role: .toolResult, content: trimmed))
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

    private func firstNonEmptyTrimmedStringValue(for keys: [String], in arguments: [String: Any]) -> String? {
        for key in keys {
            guard let value = arguments[key] as? String else {
                continue
            }

            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }

        return nil
    }

    private func makeCodexMessages(
        role: AudioTranscriptMessageRole,
        content: String
    ) -> [CodexInputMessage] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        switch role {
        case .user:
            return [
                CodexInputMessage(
                    role: "user",
                    content: [CodexInputContent(type: "input_text", text: trimmed)]
                )
            ]
        case .assistant, .toolResult:
            return [
                CodexInputMessage(
                    role: "assistant",
                    content: [CodexInputContent(type: "output_text", text: trimmed)]
                )
            ]
        case .status, .error:
            return []
        }
    }
}

private enum AudioModeCodexCoordinatorError: LocalizedError {
    case invalidTaskStartDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidTaskStartDate(let value):
            return "Codex provided an invalid task start date: \(value)"
        }
    }
}

final class CodexStructuredToolAudioModeAdapter: AudioModeCodexExecuting {
    private let tool: CodexStructuredTool

    init(tool: CodexStructuredTool) {
        self.tool = tool
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        try await tool.converse(
            messages: messages,
            state: state,
            tools: tools,
            instructions: instructions
        )
    }
}

extension AudioModeCodexCoordinator {
    static let defaultIntentInstructions: String =
        "You are an assistant with two tools: create_task for to-dos and Notes for fleeting notes saved in the app. If the user's intent is clear, call the appropriate tool. For create_task, watch for dates, days, times, and dayparts like morning, afternoon, and evening. If the user gives timing information, include start_date as a normalized ISO-8601 string. If the user gives only a date and no time, treat it as afternoon. Mention any important scheduling assumption in the description so the saved task preserves the user's intent. If start_date is present and duration is omitted, the app will default duration to 900 seconds. If the input is vague or missing details, do not call a tool; instead, respond with a clarification question."

    static let defaultIntentTools: [CodexTool] = [
        CodexTool(
            name: "create_task",
            description: "Create a to-do item when the user wants to add a task. Include start_date when the user mentions a date, time, morning, afternoon, or evening. Use an ISO-8601 string when possible. If only a date is known, assume afternoon and mention that assumption in description. If start_date is present and duration is omitted, the app defaults duration to 900 seconds.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Short task title.")
                    ]),
                    "description": .object([
                        "type": .string("string"),
                        "description": .string("Optional task details. Mention scheduling assumptions here when you infer a default time such as afternoon.")
                    ]),
                    "start_date": .object([
                        "type": .string("string"),
                        "description": .string("Optional normalized ISO-8601 start date. If the user gives only a date and no time, use that date with an afternoon time.")
                    ]),
                    "duration": .object([
                        "type": .string("number"),
                        "description": .string("Optional task duration in seconds. If omitted for scheduled tasks, the app defaults to 900 seconds.")
                    ])
                ]),
                "required": .array([
                    .string("title")
                ])
            ])
        ),
        CodexTool(
            name: "Notes",
            description: "Create a fleeting note in the app when the user wants to save general information or a note.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "content": .object([
                        "type": .string("string")
                    ]),
                    "note": .object([
                        "type": .string("string")
                    ])
                ]),
                "required": .array([
                    .string("content")
                ])
            ])
        )
    ]

    private static let iso8601DateFormatters: [ISO8601DateFormatter] = {
        let formatterWithInternetDateTime = ISO8601DateFormatter()
        formatterWithInternetDateTime.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
        formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        let formatterWithoutTimezoneSeparator = ISO8601DateFormatter()
        formatterWithoutTimezoneSeparator.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatterWithoutTimezoneSeparator.timeZone = .current

        return [
            formatterWithInternetDateTime,
            formatterWithoutFractionalSeconds,
            formatterWithoutTimezoneSeparator
        ]
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
