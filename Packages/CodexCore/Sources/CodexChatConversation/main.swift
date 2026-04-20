import CodexCore
import Darwin
import Foundation

@main
struct CodexChatConversation {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        EnvironmentLoader.loadLocalEnvFileIfPresent()

        let command = CommandLineOptions(arguments: CommandLine.arguments)
        if command.showHelp {
            print(command.helpText)
            return
        }

        guard let accessToken = EnvironmentLoader.value(for: [
            "CODEX_ACCESS_TOKEN",
            "CODEX_AUTH_TOKEN",
            "codex_auth_token"
        ]) else {
            throw ScriptError.missingAccessToken
        }

        guard let accountID = EnvironmentLoader.value(for: [
            "CODEX_ACCOUNT_ID",
            "CHATGPT_ACCOUNT_ID",
            "chatgpt_account_id"
        ]) else {
            throw ScriptError.missingAccountID
        }

        let baseURL = try EnvironmentLoader.optionalURL(for: "CODEX_RESPONSES_URL")
        let timeout = EnvironmentLoader.optionalDouble(for: "CODEX_TIMEOUT_SECONDS") ?? 60
        let session = ChatSession(
            client: CodexStructuredTool(
                access_token: accessToken,
                account_id: accountID,
                model: EnvironmentLoader.value(for: ["CODEX_MODEL"]),
                url: baseURL,
                timeout: timeout
            )
        )

        if let prompt = command.prompt {
            try await session.submit(prompt)
            return
        }

        print("Codex chat conversation")
        print("Using Neural Loop dummy tools: create_task, create_sub_task, and Notes.")
        print("Grocery and shopping-list prompts should be split into one parent task plus item subtasks.")
        print("Type /quit to exit, /reset to clear conversation state, or /state to print response state.")

        while true {
            FileHandle.standardOutput.write(Data("\nuser> ".utf8))
            guard let line = readLine(strippingNewline: true) else {
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            switch trimmed {
            case "/quit", "/exit":
                return
            case "/reset":
                session.reset()
                print("Conversation reset.")
            case "/state":
                session.printState()
            default:
                try await session.submit(trimmed)
            }
        }
    }
}

private final class ChatSession {
    private let client: CodexStructuredTool
    private let toolExecutor = DummyToolExecutor()
    private var state = CodexConversationState()
    private var messages: [CodexInputMessage] = []
    private let instructions = NeuralLoopCodexIntents.getDefaultIntentInstructions(currentDateISO: Date().ISO8601Format())

    init(client: CodexStructuredTool) {
        self.client = client
    }

    func reset() {
        state = CodexConversationState()
        messages.removeAll()
    }

    func printState() {
        print("previous_response_id: \(state.previousResponseID ?? "nil")")
        print("conversation_id: \(state.conversationID ?? "nil")")
        print("messages: \(messages.count)")
    }

    func submit(_ prompt: String) async throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return
        }

        let requestMessages = messages + [Self.userMessage(trimmedPrompt)]
        let result = try await client.converse(
            messages: requestMessages,
            state: state,
            tools: NeuralLoopCodexIntents.defaultIntentTools,
            instructions: instructions
        )

        messages = requestMessages
        state = result.state

        switch result.action {
        case .clarify(let text):
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return
            }

            print("\ncodex> \(trimmedText)")
            messages.append(Self.assistantMessage(trimmedText))

        case .callTool(let name, let arguments):
            let resultText = try toolExecutor.execute(name: name, arguments: arguments)
            print("\ntool:\(name)> \(resultText)")
            messages.append(Self.assistantMessage(resultText))
        }
    }

    private static func userMessage(_ text: String) -> CodexInputMessage {
        CodexInputMessage(
            role: "user",
            content: [CodexInputContent(type: "input_text", text: text)]
        )
    }

    private static func assistantMessage(_ text: String) -> CodexInputMessage {
        CodexInputMessage(
            role: "assistant",
            content: [CodexInputContent(type: "output_text", text: text)]
        )
    }
}

private struct DummyToolExecutor {
    func execute(name: String, arguments: [String: Any]) throws -> String {
        switch normalized(name) {
        case "create_task":
            return try createTask(arguments)
        case "create_sub_task":
            return try createSubTask(arguments)
        case "notes", "create_note":
            return try createNote(arguments)
        default:
            throw ScriptError.unknownTool(name)
        }
    }

    private func createTask(_ arguments: [String: Any]) throws -> String {
        guard let title = firstNonEmptyString(for: ["title"], in: arguments) else {
            throw ScriptError.invalidToolArguments("create_task requires a non-empty title.")
        }

        var payload: [String: Any] = [
            "id": "dummy-task-\(UUID().uuidString)",
            "title": title
        ]

        if let description = firstNonEmptyString(for: ["description", "content"], in: arguments) {
            payload["description"] = description
        }

        if let startDate = firstNonEmptyString(for: ["start_date"], in: arguments) {
            payload["start_date"] = startDate
            payload["duration"] = numberValue(for: "duration", in: arguments) ?? 900
        } else if let duration = numberValue(for: "duration", in: arguments) {
            payload["duration"] = duration
        }

        return "Dummy task created:\n\(prettyJSON(payload))"
    }

    private func createNote(_ arguments: [String: Any]) throws -> String {
        guard let content = firstNonEmptyString(for: ["content", "note"], in: arguments) else {
            throw ScriptError.invalidToolArguments("Notes requires non-empty content.")
        }

        let payload: [String: Any] = [
            "id": "dummy-note-\(UUID().uuidString)",
            "content": content
        ]
        return "Dummy note created:\n\(prettyJSON(payload))"
    }

    private func createSubTask(_ arguments: [String: Any]) throws -> String {
        guard let taskID = int64Value(for: ["task_id"], in: arguments), taskID > 0 else {
            throw ScriptError.invalidToolArguments("create_sub_task requires a valid parent task_id and a non-empty title.")
        }

        guard let title = firstNonEmptyString(for: ["title"], in: arguments) else {
            throw ScriptError.invalidToolArguments("create_sub_task requires a valid parent task_id and a non-empty title.")
        }

        let payload: [String: Any] = [
            "id": "dummy-subtask-\(UUID().uuidString)",
            "task_id": taskID,
            "title": title,
            "is_completed": false
        ]

        return "Dummy subtask created:\n\(prettyJSON(payload))"
    }

    private func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func firstNonEmptyString(for keys: [String], in arguments: [String: Any]) -> String? {
        for key in keys {
            guard let value = arguments[key] as? String else {
                continue
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func numberValue(for key: String, in arguments: [String: Any]) -> Double? {
        if let value = arguments[key] as? Double {
            return value
        }
        if let value = arguments[key] as? Int {
            return Double(value)
        }
        if let value = arguments[key] as? String {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func int64Value(for keys: [String], in arguments: [String: Any]) -> Int64? {
        let lowerBound = Double(Int64.min)
        let upperBound = Double(Int64.max)

        for key in keys {
            if let value = arguments[key] as? Int64 {
                return value
            }
            if let value = arguments[key] as? Int {
                return Int64(value)
            }
            if let value = arguments[key] as? Double {
                guard value.isFinite,
                      value >= lowerBound,
                      value <= upperBound,
                      value.rounded(.towardZero) == value else {
                    continue
                }
                return Int64(value)
            }
            if let value = arguments[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let parsed = Int64(trimmed) else {
                    continue
                }
                return parsed
            }
        }

        return nil
    }

    private func prettyJSON(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(
                  withJSONObject: payload,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8)
        else {
            return String(describing: payload)
        }

        return text
    }
}

private struct CommandLineOptions {
    let showHelp: Bool
    let prompt: String?

    init(arguments: [String]) {
        let values = Array(arguments.dropFirst())
        showHelp = values.contains("-h") || values.contains("--help")
        let promptParts = values.filter { $0 != "-h" && $0 != "--help" }
        prompt = promptParts.isEmpty ? nil : promptParts.joined(separator: " ")
    }

    var helpText: String {
        """
        Usage:
          swift run CodexChatConversation [prompt]
          bash Scripts/chat_conversation.sh [prompt]

        Environment:
          CODEX_ACCESS_TOKEN      Required. ChatGPT/Codex bearer token.
          CODEX_ACCOUNT_ID        Required. ChatGPT account id.
          CODEX_MODEL             Optional. Defaults to CodexStructuredTool default.
          CODEX_RESPONSES_URL     Optional. Defaults to the Codex responses endpoint.
          CODEX_TIMEOUT_SECONDS   Optional. Defaults to 60.

        Put local credentials in Packages/CodexCore/.env. That file is gitignored.
        """
    }
}

private enum EnvironmentLoader {
    static func loadLocalEnvFileIfPresent() {
        for envFile in envFileCandidates() {
            guard FileManager.default.fileExists(atPath: envFile.path) else {
                continue
            }

            guard let contents = try? String(contentsOf: envFile, encoding: .utf8) else {
                continue
            }

            for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
                guard let assignment = parseAssignment(String(line)) else {
                    continue
                }
                setenv(assignment.key, assignment.value, 0)
            }
        }
    }

    static func value(for keys: [String]) -> String? {
        for key in keys {
            guard let rawValue = getenv(key) else {
                continue
            }

            let value = String(cString: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func optionalURL(for key: String) throws -> URL? {
        guard let rawValue = value(for: [key]) else {
            return nil
        }

        guard let url = URL(string: rawValue) else {
            throw ScriptError.invalidURL(rawValue)
        }
        return url
    }

    static func optionalDouble(for key: String) -> Double? {
        guard let value = value(for: [key]) else {
            return nil
        }
        return Double(value)
    }

    private static func envFileCandidates() -> [URL] {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return unique([
            currentDirectory.appendingPathComponent(".env"),
            packageRoot.appendingPathComponent(".env")
        ])
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []

        for url in urls {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else {
                continue
            }

            seen.insert(path)
            result.append(url)
        }

        return result
    }

    private static func parseAssignment(_ line: String) -> (key: String, value: String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
            return nil
        }

        let assignmentLine: String
        if trimmedLine.hasPrefix("export ") {
            assignmentLine = String(trimmedLine.dropFirst("export ".count))
        } else {
            assignmentLine = trimmedLine
        }

        guard let equalsIndex = assignmentLine.firstIndex(of: "=") else {
            return nil
        }

        let key = assignmentLine[..<equalsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        var value = assignmentLine[assignmentLine.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if value.count >= 2,
           let first = value.first,
           let last = value.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            value.removeFirst()
            value.removeLast()
        }

        guard !key.isEmpty else {
            return nil
        }

        return (key, value)
    }
}

private enum ScriptError: LocalizedError {
    case missingAccessToken
    case missingAccountID
    case invalidURL(String)
    case unknownTool(String)
    case invalidToolArguments(String)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Missing CODEX_ACCESS_TOKEN. Add it to Packages/CodexCore/.env or export it in the shell."
        case .missingAccountID:
            return "Missing CODEX_ACCOUNT_ID. Add it to Packages/CodexCore/.env or export it in the shell."
        case .invalidURL(let value):
            return "Invalid CODEX_RESPONSES_URL: \(value)"
        case .unknownTool(let name):
            return "Codex returned an unknown tool call: \(name)"
        case .invalidToolArguments(let message):
            return message
        }
    }
}
