import Foundation
import Combine
import CodexCore

protocol AIModeCodexExecuting {
    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult

    func reformat(
        _ rawTranscript: String,
        instructions: String
    ) async throws -> String
}

@MainActor
protocol AIModeCodexModel: AnyObject {
    var llm_enabled: Bool { get }
    var codexAccessToken: String? { get }
    var codexAccountID: String? { get }
    func validCodexCredentials() async -> CodexCredentials?
    func getTask(by id: Int64) -> Tasks?
    func saveTask(_ task: Tasks) async -> Tasks?
    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks?
    func saveFleetingNote(_ request: CreateFleetingNoteRequest) async -> FleetingNote?
    func createWorkReminder(title: String, notes: String?) async throws -> WorkReminder
}

@MainActor
final class AIModeCodexCoordinator: ObservableObject {
    @Published private(set) var conversationFeed: [AITranscriptMessage] = []
    @Published private(set) var codexState = CodexConversationState()
    @Published private(set) var isSending = false
    @Published private(set) var isReformatting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastNoteResultSource: FleetingNoteSource?

    private let model: any AIModeCodexModel
    private let codexClient: (any AIModeCodexExecuting)?
    private var pendingTranscripts: [String] = []
    private var drainTask: Task<Void, Never>?
    private var codexMessages: [CodexInputMessage] = []

    let intentTools: [CodexTool] = NeuralLoopCodexIntents.defaultIntentTools
    var intentInstructions: String = NeuralLoopCodexIntents.getDefaultIntentInstructions(currentDateISO: ISO8601DateFormatter().string(from: Date()))

    var reformatInstructions: String {
        var toolContext = ""
        for tool in intentTools {
            toolContext += "- \(tool.name): \(tool.description)\n"
        }

        return """
        Act as an expert AI dictation assistant. I will provide you with raw, stream-of-consciousness voice transcriptions. Your job is to transform this raw input into clean, perfectly formatted text.

        The user is speaking to a productivity app that supports the following actions:
        \(toolContext)
        Keep this context in mind when cleaning the transcript. Preserve any references to tasks, shopping lists, notes, dates, times, locations, items, or work/personal context — these are meaningful to the app.

        Follow these rules strictly:
        1. **Clean up:** Remove all filler words (um, uh, like), false starts, stutters, and conversational tangents.
        2. **Fix Mechanics:** Correct grammar and spelling. Add natural punctuation, capitalization, and logical paragraph breaks.
        3. **Preserve Intent:** Do not remove or rephrase words that signal what the user wants the app to do (e.g., "create a task", "add a note", "shopping list for Tesco", "remind me tomorrow morning"). These phrases drive downstream tool calls.
        4. **Context-Aware Reformatting:** Analyze the intent and structure the text automatically:
           - If it sounds like an email ("Hey Sarah..."), format it with proper line breaks and sign-offs.
           - If it's a brain dump of multiple items, organize them into clean bullet points.
           - If it's a quick message, keep it concise and punchy.
        5. **Execute Voice Commands:** If the text includes an explicit command (e.g., "Format this as a formal report" or "Make this a polite Slack message"), apply that style to the rest of the content.
        6. **Total Fidelity:** Do NOT hallucinate external facts, change my core meaning, or add robotic AI fluff. Never start with "Here is your text:" or "Sure!". Output ONLY the final, polished text.
        """
    }

    var bannerText: String? {
        if isReformatting {
            return "Reformatting transcript…"
        }
        if isSending {
            return statusMessage ?? "Sending to Codex..."
        }
        return errorMessage ?? statusMessage
    }

    var bannerTone: AIModeBannerTone? {
        if errorMessage != nil {
            return .error
        }
        if statusMessage == "LLM access is disabled." {
            return .warning
        }
        if isReformatting || statusMessage != nil {
            return .info
        }
        return nil
    }

    var isLLMDisabled: Bool {
        statusMessage == "LLM access is disabled."
    }

    var viewData: AIModeConversationViewData {
        AIModeConversationViewData(
            messages: conversationFeed,
            bannerText: bannerText,
            bannerTone: bannerTone,
            isSending: isSending,
            isReformatting: isReformatting,
            isLLMDisabled: isLLMDisabled,
            noteTargetStatusText: lastNoteResultSource.map { "Notes: \($0.displayName)" }
        )
    }

    init(
        model: any AIModeCodexModel,
        codexClient: (any AIModeCodexExecuting)? = nil,
    ) {
        self.model = model
        self.codexClient = codexClient
    }

    func resetConversation() {
        drainTask?.cancel()
        drainTask = nil
        pendingTranscripts.removeAll()
        conversationFeed.removeAll()
        codexMessages.removeAll()
        intentInstructions = NeuralLoopCodexIntents.getDefaultIntentInstructions(currentDateISO: ISO8601DateFormatter().string(from: Date()))
        codexState = CodexConversationState()
        isSending = false
        isReformatting = false
        errorMessage = nil
        statusMessage = nil
        lastNoteResultSource = nil
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

    func handleCapturedImage(_ imagePayload: AIModeImagePayload) async {
        guard model.llm_enabled else {
            appendStatus("LLM access is disabled.")
            return
        }

        guard let client = await resolvedCodexClient() else {
            appendError("Codex client is unavailable.")
            return
        }

        let prompt = "Tell me what this image is about."
        errorMessage = nil
        conversationFeed.append(
            .init(
                role: .user,
                content: "Captured image sent to Codex.",
                imagePreviewData: imagePayload.previewData
            )
        )
        isSending = true
        appendStatus("Sending image to Codex...")

        defer {
            isSending = false
            if statusMessage == "Sending image to Codex..." {
                statusMessage = nil
            }
        }

        do {
            let imageMessage = CodexInputMessage(
                role: "user",
                content: [
                    CodexInputContent(type: "input_text", text: prompt),
                    CodexInputContent(
                        type: "input_image",
                        image_url: imagePayload.dataURL,
                        detail: "high"
                    )
                ]
            )
            let requestMessages = codexMessages + [imageMessage]
            let result = try await client.converse(
                messages: requestMessages,
                state: codexState,
                tools: intentTools,
                instructions: intentInstructions
            )

            if Task.isCancelled {
                return
            }

            codexMessages.append(
                CodexInputMessage(
                    role: "user",
                    content: [CodexInputContent(type: "input_text", text: "\(prompt) [Captured image attached]")]
                )
            )
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

    func handleCameraUnavailable() {
        appendError("Camera is unavailable on this device.")
    }

    func handleImagePreparationFailure(_ error: Error) {
        appendError(error.localizedDescription)
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

        guard let client = await resolvedCodexClient() else {
            appendError("Codex client is unavailable.")
            return
        }

        // Step 1: Reformat the raw transcript
        let reformattedTranscript: String
        do {
            isReformatting = true
            let polished = try await client.reformat(
                transcript,
                instructions: reformatInstructions
            )

            if Task.isCancelled {
                isReformatting = false
                return
            }

            reformattedTranscript = polished

            // Update the last user bubble with the reformatted text
            if let lastUserIndex = conversationFeed.lastIndex(where: { $0.role == .user && $0.content == transcript }) {
                conversationFeed[lastUserIndex] = AITranscriptMessage(
                    id: conversationFeed[lastUserIndex].id,
                    role: .user,
                    content: reformattedTranscript,
                    rawContent: transcript
                )
            }
        } catch is CancellationError {
            isReformatting = false
            return
        } catch {
            if Task.isCancelled {
                isReformatting = false
                return
            }
            // Fall back to raw transcript silently on reformat failure
            reformattedTranscript = transcript
        }
        isReformatting = false

        // Step 2: Send the reformatted transcript to Codex for intent detection
        isSending = true
        appendStatus("Sending to Codex...")

        defer {
            isSending = false
            if statusMessage == "Sending to Codex..." {
                statusMessage = nil
            }
        }

        do {
            let requestMessages = codexMessages + makeCodexMessages(role: .user, content: reformattedTranscript)
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
        case "create_shopping_list":
            try await handleCreateShoppingList(arguments: arguments)
        case "notes":
            await handleCreateNote(arguments: arguments)
        case "make_task_deadline":
            await handleMakeTaskDeadline(arguments: arguments)
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

        await saveTaskWithSubTasks(
            task,
            subTaskTitles: subTaskTitlesValue(in: arguments),
            confirmationSubject: "Task"
        )
    }

    private func handleCreateShoppingList(arguments: [String: Any]) async throws {
        guard let location = firstNonEmptyTrimmedStringValue(for: ["location", "store", "place"], in: arguments) else {
            appendError("Codex did not provide a shopping list location.")
            return
        }

        let itemTitles = shoppingItemTitlesValue(in: arguments)
        guard !itemTitles.isEmpty else {
            appendError("Codex did not provide shopping list items.")
            return
        }

        let startDate = try parseShoppingListStartDate(arguments: arguments)
        let title = shoppingListTitle(location: location)
        let task = Tasks(
            id: nil,
            title: title,
            description: shoppingListDescription(location: location, items: itemTitles),
            priority: 0,
            goal_id: nil,
            lifearea_id: nil,
            is_completed: false,
            is_deadline: false,
            completed_at: nil,
            recursion_rule: nil,
            start_date: startDate,
            duration: 900,
            created_at: nil,
            updated_at: nil
        )

        await saveTaskWithSubTasks(
            task,
            subTaskTitles: itemTitles,
            confirmationSubject: "Shopping list"
        )
    }

    private func parseTaskSchedule(arguments: [String: Any]) throws -> (startDate: Date?, duration: Double?) {
        guard let rawStartDate = optionalStringValue(for: ["start_date"], in: arguments), !rawStartDate.isEmpty else {
            return (nil, nil)
        }

        guard let startDate = parseStartDate(rawStartDate) else {
            throw AIModeCodexCoordinatorError.invalidTaskStartDate(rawStartDate)
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
            hour: 15,
            minute: 0,
            second: 0
        ))
    }

    private func parseShoppingListStartDate(arguments: [String: Any]) throws -> Date {
        guard let rawStartDate = optionalStringValue(for: ["start_date"], in: arguments), !rawStartDate.isEmpty else {
            return defaultShoppingListStartDate()
        }

        guard let startDate = parseStartDate(rawStartDate) else {
            throw AIModeCodexCoordinatorError.invalidShoppingListStartDate(rawStartDate)
        }

        return startDate
    }

    private func defaultShoppingListStartDate(now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 15,
            minute: 0,
            second: 0
        )) ?? now
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

    private func subTaskTitlesValue(in arguments: [String: Any]) -> [String] {
        guard let rawSubTasks = arrayValue(for: ["sub_tasks"], in: arguments) else {
            return []
        }

        return rawSubTasks.compactMap { item in
            guard let subTaskArguments = item as? [String: Any] else {
                return nil
            }

            return firstNonEmptyTrimmedStringValue(for: ["title"], in: subTaskArguments)
        }
    }

    private func shoppingItemTitlesValue(in arguments: [String: Any]) -> [String] {
        guard let rawItems = arrayValue(for: ["items"], in: arguments) else {
            return []
        }

        return rawItems.compactMap { item in
            if let stringItem = item as? String {
                let trimmedItem = stringItem.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedItem.isEmpty ? nil : trimmedItem
            }

            guard let itemArguments = item as? [String: Any] else {
                return nil
            }

            return firstNonEmptyTrimmedStringValue(for: ["title", "name", "item"], in: itemArguments)
        }
    }

    private func arrayValue(for keys: [String], in arguments: [String: Any]) -> [Any]? {
        for key in keys {
            if let value = arguments[key] as? [Any] {
                return value
            }
            if let value = arguments[key] as? NSArray {
                return value as? [Any]
            }
        }

        return nil
    }

    private func saveTaskWithSubTasks(
        _ task: Tasks,
        subTaskTitles: [String],
        confirmationSubject: String
    ) async {
        guard let savedTask = await model.saveTask(task) else {
            appendError("\(confirmationSubject) could not be saved.")
            return
        }

        var createdSubTaskTitles: [String] = []
        var failedSubTaskTitles: [String] = []

        guard let savedTaskID = savedTask.id, savedTaskID > 0 else {
            appendToolResult(createTaskConfirmationText(
                subject: confirmationSubject,
                taskID: nil,
                title: savedTask.title,
                createdSubTaskTitles: createdSubTaskTitles,
                failedSubTaskTitles: subTaskTitles
            ), kind: .taskCreated)
            return
        }

        for subTaskTitle in subTaskTitles {
            guard let savedSubTask = await model.addSubTask(subTaskTitle, taskId: savedTaskID) else {
                failedSubTaskTitles.append(subTaskTitle)
                continue
            }

            createdSubTaskTitles.append(savedSubTask.title)
        }

        appendToolResult(createTaskConfirmationText(
            subject: confirmationSubject,
            taskID: savedTaskID,
            title: savedTask.title,
            createdSubTaskTitles: createdSubTaskTitles,
            failedSubTaskTitles: failedSubTaskTitles
        ), kind: .taskCreated)
    }

    private func createTaskConfirmationText(
        subject: String,
        taskID: Int64?,
        title: String,
        createdSubTaskTitles: [String],
        failedSubTaskTitles: [String]
    ) -> String {
        let taskIDText = taskID.map(String.init) ?? "unknown"
        var components = ["\(subject) created (id: \(taskIDText)): \(title)"]

        if !createdSubTaskTitles.isEmpty {
            components.append("Subtasks created: \(createdSubTaskTitles.joined(separator: ", "))")
        }

        if !failedSubTaskTitles.isEmpty {
            components.append("Subtasks not created: \(failedSubTaskTitles.joined(separator: ", "))")
        }

        return components.joined(separator: ". ") + "."
    }

    private func shoppingListTitle(location: String) -> String {
        return "Shopping list: \(location)"
    }

    private func shoppingListDescription(location: String, items: [String]) -> String {
        let itemText = items.joined(separator: ", ")
        return "Shopping list for \(location). Items: \(itemText)."
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

        switch noteSource(in: arguments) {
        case .personal:
            let request = CreateFleetingNoteRequest(note: trimmedNote)
            guard let savedNote = await model.saveFleetingNote(request) else {
                appendError("Personal note could not be saved.")
                return
            }

            lastNoteResultSource = .personal
            appendToolResult(
                "Personal note created (id: \(savedNote.id)): \(savedNote.note)",
                kind: .personalNoteCreated
            )
        case .work:
            do {
                let savedReminder = try await model.createWorkReminder(title: trimmedNote, notes: nil)
                lastNoteResultSource = .work
                appendToolResult(
                    "Work note created: \(savedReminder.title)",
                    kind: .workNoteCreated
                )
            } catch {
                lastNoteResultSource = .work
                appendError(error.localizedDescription)
            }
        case .invalid:
            appendError("Codex provided an unknown note source.")
        }
    }

    private func handleMakeTaskDeadline(arguments: [String: Any]) async {
        guard let taskIDRaw = arguments["task_id"] else {
            appendError("Codex did not provide a task ID.")
            return
        }
        
        let taskID: Int64
        if let idInt = taskIDRaw as? Int {
            taskID = Int64(idInt)
        } else if let idDouble = taskIDRaw as? Double {
            taskID = Int64(idDouble)
        } else if let idString = taskIDRaw as? String, let parsed = Int64(idString) {
            taskID = parsed
        } else {
            appendError("Codex provided an invalid task ID format.")
            return
        }

        guard let existingTask = model.getTask(by: taskID) else {
            appendError("Task with ID \(taskID) not found.")
            return
        }

        let updatedTask = Tasks(
            id: existingTask.id,
            title: existingTask.title,
            description: existingTask.description,
            priority: existingTask.priority,
            goal_id: existingTask.goal_id,
            lifearea_id: existingTask.lifearea_id,
            is_completed: existingTask.is_completed,
            is_deadline: true,
            completed_at: existingTask.completed_at,
            recursion_rule: existingTask.recursion_rule,
            start_date: existingTask.start_date,
            duration: existingTask.duration,
            created_at: existingTask.created_at,
            updated_at: existingTask.updated_at
        )

        guard await model.saveTask(updatedTask) != nil else {
            appendError("Failed to update task \(taskID).")
            return
        }

        appendToolResult("Task (id: \(taskID)) marked as a deadline.", kind: .taskUpdated)
    }

    private func resolvedCodexClient() async -> (any AIModeCodexExecuting)? {
        if let codexClient {
            return codexClient
        }

        guard let credentials = await model.validCodexCredentials() else {
            return nil
        }

        return CodexStructuredToolAIModeAdapter(
            tool: CodexStructuredTool(access_token: credentials.accessToken, account_id: credentials.accountID)
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

    private func appendToolResult(_ text: String, kind: AIToolResultKind? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        conversationFeed.append(.init(role: .toolResult, content: trimmed, toolResultKind: kind))
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

    private enum NoteToolSource {
        case personal
        case work
        case invalid
    }

    private func noteSource(in arguments: [String: Any]) -> NoteToolSource {
        guard let rawSource = firstNonEmptyTrimmedStringValue(for: ["source", "scope"], in: arguments) else {
            return .personal
        }

        switch rawSource.lowercased() {
        case "personal":
            return .personal
        case "work":
            return .work
        default:
            return .invalid
        }
    }

    private func makeCodexMessages(
        role: AITranscriptMessageRole,
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

private enum AIModeCodexCoordinatorError: LocalizedError {
    case invalidTaskStartDate(String)
    case invalidShoppingListStartDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidTaskStartDate(let value):
            return "Codex provided an invalid task start date: \(value)"
        case .invalidShoppingListStartDate(let value):
            return "Codex provided an invalid shopping list start date: \(value)"
        }
    }
}

final class CodexStructuredToolAIModeAdapter: AIModeCodexExecuting {
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

    func reformat(
        _ rawTranscript: String,
        instructions: String
    ) async throws -> String {
        try await tool.reformat(
            rawTranscript,
            instructions: instructions
        )
    }
}

extension AIModeCodexCoordinator {

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
