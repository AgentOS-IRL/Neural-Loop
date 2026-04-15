import Foundation

public enum CodexStructuredMethod: String {
    case jsonSchema
    case jsonMode
    case functionCalling
}

public struct CodexStructuredResult<Parsed> {
    public let raw: String
    public let parsed: Parsed

    public init(raw: String, parsed: Parsed) {
        self.raw = raw
        self.parsed = parsed
    }
}

public enum CodexAction {
    case callTool(name: String, arguments: [String: Any])
    case clarify(text: String)
}

public protocol CodexSchemaProviding {
    static var codexSchemaPayload: CodexJSONSchemaPayload { get }
}
public struct CodexTool: Codable, Equatable {
    public let name: String
    public let description: String
    public let parameters: JSONValue

    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    // Simplified CodingKeys to flatten the structure
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case parameters
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.parameters = try container.decode(JSONValue.self, forKey: .parameters)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode everything at the top level
        try container.encode("function", forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(parameters, forKey: .parameters)
    }
}

public struct CodexJSONSchemaPayload: Equatable {
    public let name: String
    public let schema: JSONValue

    public init(name: String, schema: JSONValue) {
        self.name = name
        self.schema = schema
    }
}

public enum CodexStructuredToolError: Error, LocalizedError, Equatable {
    case invalidURL
    case missingSchemaPayload
    case malformedStreamEvent(String)
    case malformedStructuredResponse(String)
    case malformedToolArguments(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "CodexStructuredTool was configured with an invalid URL."
        case .missingSchemaPayload:
            return "No JSON schema payload was provided for jsonSchema mode."
        case .malformedStreamEvent(let payload):
            return "Malformed Codex SSE event: \(payload)"
        case .malformedStructuredResponse(let raw):
            return "Could not decode structured Codex response: \(raw)"
        case .malformedToolArguments(let raw):
            return "Could not decode Codex tool arguments: \(raw)"
        case .transport(let message):
            return "Codex transport error: \(message)"
        }
    }
}

public final class CodexStructuredTool {
    public let accessToken: String
    public let accountID: String
    public let baseURL: URL
    public let model: String
    public let instructions: String
    public let timeout: TimeInterval
    public let sessionConfiguration: URLSessionConfiguration
    private let streamingChunksProvider: ((URLRequest) async throws -> [Data])?

    private let requestEncoder = JSONEncoder()
    private let responseDecoder = JSONDecoder()

    public init(
        access_token: String,
        account_id: String,
        model: String? = nil,
        url: URL? = nil,
        instructions: String? = nil,
        timeout: TimeInterval = 60,
        sessionConfiguration: URLSessionConfiguration = .default,
        streamingChunksProvider: ((URLRequest) async throws -> [Data])? = nil
    ) {
        self.accessToken = access_token
        self.accountID = account_id
        self.baseURL = url ?? URL(string: "https://chatgpt.com/backend-api/codex/responses")!
        self.model = model ?? "gpt-5.4-mini"
        self.instructions = instructions ?? "You are a helpful assistant."
        self.timeout = timeout

        sessionConfiguration.timeoutIntervalForRequest = timeout
        sessionConfiguration.timeoutIntervalForResource = timeout
        self.sessionConfiguration = sessionConfiguration
        self.streamingChunksProvider = streamingChunksProvider
        self.requestEncoder.outputFormatting = []
    }

    public func executeSync(_ prompt: String, url: URL? = nil) async throws -> String {
        try await _post_and_collect_text(
            prompt: prompt,
            url: url,
            instructions: nil,
            text_format: nil
        )
    }

    public func executeIntent(_ prompt: String, url: URL? = nil) async throws -> CodexAction {
        var accumulator = CodexIntentAccumulator()
        let clarification = try await _post_and_collect_text(
            prompt: prompt,
            url: url,
            instructions: Self.intentInstructions,
            text_format: nil,
            tools: Self.intentTools,
            tool_choice: "auto",
            handleEvent: { event in
                accumulator.ingest(event)
            }
        )

        if let action = try accumulator.finalizedAction() {
            return action
        }
        return .clarify(text: clarification)
    }

    public func executeStructured<T: Decodable>(
        _ prompt: String,
        as type: T.Type = T.self,
        method: CodexStructuredMethod = .jsonSchema,
        strict: Bool = false,
        schema: CodexJSONSchemaPayload? = nil,
        url: URL? = nil
    ) async throws -> T {
        let result = try await executeStructuredWithRaw(
            prompt,
            as: type,
            method: method,
            strict: strict,
            schema: schema,
            url: url
        )
        return result.parsed
    }

    public func executeStructuredWithRaw<T: Decodable>(
        _ prompt: String,
        as type: T.Type = T.self,
        method: CodexStructuredMethod = .jsonSchema,
        strict: Bool = false,
        schema: CodexJSONSchemaPayload? = nil,
        url: URL? = nil
    ) async throws -> CodexStructuredResult<T> {
        let textFormat: JSONValue?
        let finalPrompt: String

        switch method {
        case .jsonSchema:
            let schemaPayload = try schemaPayloadForType(type, explicitSchema: schema)
            let schemaObject = schemaPayload.schema.applyingStrictFlag(strict)
            textFormat = .object([
                "type": .string("json_schema"),
                "name": .string(schemaPayload.name),
                "strict": .bool(strict),
                "schema": schemaObject
            ])
            finalPrompt = prompt
        case .jsonMode:
            textFormat = .object([
                "type": .string("json_object")
            ])
            finalPrompt = prompt + "\nReturn only JSON.\n" + parserGuidance
        case .functionCalling:
            textFormat = nil
            finalPrompt = prompt + "\nReturn only JSON.\n" + parserGuidance
        }

        let raw = try await _post_and_collect_text(
            prompt: finalPrompt,
            url: url,
            instructions: nil,
            text_format: textFormat
        )
        let parsed = try decodeStructuredResponse(raw, as: type)
        return CodexStructuredResult(raw: raw, parsed: parsed)
    }

    func _build_headers(sessionID: String = UUID().uuidString) -> [String: String] {
        [
            "Authorization": "Bearer \(accessToken)",
            "chatgpt-account-id": accountID,
            "OpenAI-Beta": "responses=experimental",
            "originator": "codex_cli_rs",
            "session_id": sessionID,
            "accept": "text/event-stream",
            "content-type": "application/json",
            "User-Agent": "python-codex-client/1.0"
        ]
    }

    func _build_body(
        prompt: String,
        instructions: String? = nil,
        text_format: JSONValue? = nil,
        tools: [CodexTool]? = nil,
        tool_choice: String? = nil
    ) -> CodexRequestBody {
        CodexRequestBody(
            model: model,
            stream: true,
            store: false,
            instructions: instructions ?? self.instructions,
            text: CodexTextConfig(verbosity: "medium", format: text_format),
            tools: tools,
            tool_choice: tool_choice,
            input: [
                CodexInputMessage(
                    role: "user",
                    content: [
                        CodexInputContent(type: "input_text", text: prompt)
                    ]
                )
            ]
        )
    }

    func _extract_text_from_event(_ event: CodexStreamEvent) -> String {
        switch event.type {
        case "response.output_text.delta":
            return event.delta ?? ""
        case "response.output_text.done", "response.completed":
            return event.response?
                .output?
                .flatMap { $0.content ?? [] }
                .compactMap { $0.text }
                .joined() ?? ""
        default:
            return ""
        }
    }

    private func _post_and_collect_text(
        prompt: String,
        url: URL?,
        instructions: String?,
        text_format: JSONValue?,
        tools: [CodexTool]? = nil,
        tool_choice: String? = nil,
        handleEvent: ((CodexStreamEvent) throws -> Void)? = nil
    ) async throws -> String {
        let request = try _build_request(
            prompt: prompt,
            url: url,
            instructions: instructions,
            text_format: text_format,
            tools: tools,
            tool_choice: tool_choice
        )

        if let streamingChunksProvider {
            do {
                let chunks = try await streamingChunksProvider(request)
                return try collectText(
                    from: chunks,
                    handleEvent: handleEvent,
                    extractText: { [weak self] event in
                        self?._extract_text_from_event(event) ?? ""
                    }
                )
            } catch let error as CodexStructuredToolError {
                throw error
            } catch {
                throw CodexStructuredToolError.transport(error.localizedDescription)
            }
        }

        let session = URLSession(configuration: sessionConfiguration)
        do {
            let (bytes, response) = try await session.bytes(for: request)
            try await validate(bytes: bytes, response: response)
            return try await collectText(
                from: bytes,
                handleEvent: handleEvent,
                extractText: { [weak self] event in
                    self?._extract_text_from_event(event) ?? ""
                }
            )
        } catch let error as CodexStructuredToolError {
            throw error
        } catch {
            throw CodexStructuredToolError.transport(error.localizedDescription)
        }
    }

    private func _build_request(
        prompt: String,
        url: URL? = nil,
        instructions: String? = nil,
        text_format: JSONValue? = nil,
        tools: [CodexTool]? = nil,
        tool_choice: String? = nil
    ) throws -> URLRequest {
        let requestURL = url ?? baseURL

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout

        let headers = _build_headers()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body = _build_body(
            prompt: prompt,
            instructions: instructions,
            text_format: text_format,
            tools: tools,
            tool_choice: tool_choice
        )
        request.httpBody = try requestEncoder.encode(body)
        return request
    }

    private func schemaPayloadForType<T>(_ type: T.Type, explicitSchema: CodexJSONSchemaPayload?) throws -> CodexJSONSchemaPayload {
        if let explicitSchema {
            return explicitSchema
        }
        if let provider = type as? CodexSchemaProviding.Type {
            return provider.codexSchemaPayload
        }
        throw CodexStructuredToolError.missingSchemaPayload
    }

    private func decodeStructuredResponse<T: Decodable>(_ raw: String, as type: T.Type) throws -> T {
        let normalized = normalizedCodexStructuredText(raw)
        guard let data = normalized.data(using: .utf8) else {
            throw CodexStructuredToolError.malformedStructuredResponse(raw)
        }
        do {
            return try responseDecoder.decode(T.self, from: data)
        } catch {
            throw CodexStructuredToolError.malformedStructuredResponse(raw)
        }
    }

    private var parserGuidance: String {
        "Do not include markdown fences or commentary."
    }

    private func normalizedStructuredText(_ raw: String) -> String {
        normalizedCodexStructuredText(raw)
    }
}

private func normalizedCodexStructuredText(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let start = trimmed.range(of: "```") {
        let remainder = trimmed[start.upperBound...]
        if let end = remainder.range(of: "```") {
            var content = String(remainder[..<end.lowerBound])
            if let firstNewline = content.firstIndex(of: "\n") {
                let prefix = content[..<firstNewline]
                if prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("json") {
                    content = String(content[content.index(after: firstNewline)...])
                }
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    let candidates: [(Character, Character)] = [("{", "}"), ("[", "]")]
    for (open, close) in candidates {
        if let start = trimmed.firstIndex(of: open), let end = trimmed.lastIndex(of: close), start < end {
            return String(trimmed[start..<trimmed.index(after: end)]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return trimmed
}

private extension CodexStructuredTool {
    static var intentInstructions: String {
        "You are an assistant with two tools: create_task for to-dos and Notes for general info. If the user's intent is clear, call the appropriate tool. If the input is vague or missing details, do not call a tool; instead, respond with a clarification question."
    }

    static var intentTools: [CodexTool] {
        [
            CodexTool(
                name: "create_task",
                description: "Create a to-do item when the user wants to add a task.",
                parameters: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object([
                            "type": .string("string")
                        ]),
                        "description": .object([
                            "type": .string("string")
                        ])
                    ]),
                    "required": .array([
                        .string("title"),
                        .string("description")
                    ])
                ])
            ),
            CodexTool(
                name: "Notes",
                description: "Capture general information or notes from the user.",
                parameters: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "content": .object([
                            "type": .string("string")
                        ])
                    ]),
                    "required": .array([
                        .string("content")
                    ])
                ])
            )
        ]
    }

    func validate(bytes: URLSession.AsyncBytes, response: URLResponse) async throws {
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            print("HTTP \(httpResponse.statusCode) response received.")
                        
            var data = Data()
            // 2. This 'await' requires the function to be 'async'
            for try await byte in bytes {
                data.append(byte)
            }

            if let bodyString = String(data: data, encoding: .utf8) {
                print("Response Body: \(bodyString)")
            }
            
            throw CodexStructuredToolError.transport(
                "Codex request failed with HTTP \(httpResponse.statusCode)."
            )
        }

        if let mimeType = response.mimeType, !mimeType.lowercased().contains("event-stream") {
            throw CodexStructuredToolError.transport(
                "Expected SSE text/event-stream response but received \(mimeType)."
            )
        }
    }

    func collectText(
        from chunks: [Data],
        handleEvent: ((CodexStreamEvent) throws -> Void)? = nil,
        extractText: @escaping (CodexStreamEvent) -> String
    ) throws -> String {
        var collector = CodexSSECollector(extractText: extractText, handleEvent: handleEvent)
        for chunk in chunks {
            try collector.ingest(chunk)
        }
        try collector.finish()
        return collector.collectedText
    }

    func collectText(
        from bytes: URLSession.AsyncBytes,
        handleEvent: ((CodexStreamEvent) throws -> Void)? = nil,
        extractText: @escaping (CodexStreamEvent) -> String
    ) async throws -> String {
        var collector = CodexSSECollector(extractText: extractText, handleEvent: handleEvent)
        for try await byte in bytes {
            try collector.ingest(byte)
        }
        try collector.finish()
        return collector.collectedText
    }
}

public struct CodexRequestBody: Codable, Equatable {
    public let model: String
    public let stream: Bool
    public let store: Bool
    public let instructions: String
    public let text: CodexTextConfig
    public let tools: [CodexTool]?
    public let tool_choice: String?
    public let input: [CodexInputMessage]
}

public struct CodexTextConfig: Codable, Equatable {
    public let verbosity: String
    public let format: JSONValue?
}

public struct CodexInputMessage: Codable, Equatable {
    public let role: String
    public let content: [CodexInputContent]
}

public struct CodexInputContent: Codable, Equatable {
    public let type: String
    public let text: String
}

public struct CodexStreamEvent: Decodable, Equatable {
    public let type: String
    public let delta: String?
    public let toolCalls: [CodexStreamToolCall]?
    public let response: CodexStreamResponse?

    public init(
        type: String,
        delta: String? = nil,
        toolCalls: [CodexStreamToolCall]? = nil,
        response: CodexStreamResponse? = nil
    ) {
        self.type = type
        self.delta = delta
        self.toolCalls = toolCalls
        self.response = response
    }

    static func parse(from data: Data) throws -> CodexStreamEvent {
        let payload = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = payload as? [String: Any], let type = dictionary["type"] as? String else {
            throw CodexStructuredToolError.malformedStreamEvent(String(decoding: data, as: UTF8.self))
        }

        let delta = dictionary["delta"] as? String
        let response = try CodexStreamResponse.parse(dictionary["response"])
        let toolCalls = try CodexStreamToolCall.parse(dictionary["delta"]) + CodexStreamToolCall.parse(dictionary["response"])
        return CodexStreamEvent(
            type: type,
            delta: delta,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            response: response
        )
    }
}

public struct CodexStreamResponse: Decodable, Equatable {
    public let output: [CodexStreamOutput]?

    static func parse(_ value: Any?) throws -> CodexStreamResponse? {
        guard let dictionary = value as? [String: Any] else { return nil }
        let outputValue = dictionary["output"] as? [[String: Any]]
        let output = try outputValue?.map(CodexStreamOutput.parse)
        return CodexStreamResponse(output: output)
    }
}

public struct CodexStreamOutput: Decodable, Equatable {
    public let content: [CodexStreamContent]?

    static func parse(_ value: [String: Any]) throws -> CodexStreamOutput {
        let contentValue = value["content"] as? [[String: Any]]
        let content = try contentValue?.map(CodexStreamContent.parse)
        return CodexStreamOutput(content: content)
    }
}

public struct CodexStreamContent: Decodable, Equatable {
    public let text: String?

    static func parse(_ value: [String: Any]) throws -> CodexStreamContent {
        CodexStreamContent(text: value["text"] as? String)
    }
}

public struct CodexStreamToolCall: Decodable, Equatable {
    public let id: String?
    public let index: Int?
    public let name: String?
    public let arguments: String?

    public init(id: String? = nil, index: Int? = nil, name: String? = nil, arguments: String? = nil) {
        self.id = id
        self.index = index
        self.name = name
        self.arguments = arguments
    }

    fileprivate func merged(with fragment: CodexStreamToolCall) -> CodexStreamToolCall {
        CodexStreamToolCall(
            id: fragment.id ?? id,
            index: fragment.index ?? index,
            name: fragment.name ?? name,
            arguments: (arguments ?? "") + (fragment.arguments ?? "")
        )
    }

    fileprivate var identityKey: String {
        if let index { return "index:\(index)" }
        if let id, !id.isEmpty { return id }
        if let name { return "name:\(name)" }
        return UUID().uuidString
    }

    static func parse(_ value: Any?) throws -> [CodexStreamToolCall] {
        guard let value else { return [] }
        if let array = value as? [Any] {
            return try array.flatMap(parse)
        }
        if let dictionary = value as? [String: Any] {
            var result: [CodexStreamToolCall] = []
            if let nestedToolCalls = dictionary["tool_calls"] {
                result.append(contentsOf: try parse(nestedToolCalls))
            }

            if let call = parseCall(from: dictionary) {
                result.append(call)
            }

            if let output = dictionary["output"] {
                result.append(contentsOf: try parse(output))
            }
            if let content = dictionary["content"] {
                result.append(contentsOf: try parse(content))
            }
            if let delta = dictionary["delta"] {
                result.append(contentsOf: try parse(delta))
            }
            return result
        }
        return []
    }

    private static func parseCall(from dictionary: [String: Any]) -> CodexStreamToolCall? {
        let id = dictionary["id"] as? String
        let index = dictionary["index"] as? Int
        if let function = dictionary["function"] as? [String: Any] {
            let name = function["name"] as? String
            let arguments = function["arguments"] as? String
            if id != nil || index != nil || name != nil || arguments != nil {
                return CodexStreamToolCall(id: id, index: index, name: name, arguments: arguments)
            }
        }

        let name = dictionary["name"] as? String
        let arguments = dictionary["arguments"] as? String
        if id != nil || index != nil || name != nil || arguments != nil {
            return CodexStreamToolCall(id: id, index: index, name: name, arguments: arguments)
        }
        return nil
    }
}

public enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        self = .string(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    func applyingStrictFlag(_ strict: Bool) -> JSONValue {
        guard strict else { return self }
        guard case .object(var dictionary) = self else { return self }
        dictionary["additionalProperties"] = .bool(false)
        return .object(dictionary)
    }
}

private struct CodexSSECollector {
    let extractText: (CodexStreamEvent) -> String
    let handleEvent: ((CodexStreamEvent) throws -> Void)?
    private var pendingData = Data()
    private(set) var collectedChunks: [String] = []

    init(
        extractText: @escaping (CodexStreamEvent) -> String,
        handleEvent: ((CodexStreamEvent) throws -> Void)? = nil
    ) {
        self.extractText = extractText
        self.handleEvent = handleEvent
    }

    mutating func ingest(_ data: Data) throws {
        for byte in data {
            try ingest(byte)
        }
    }

    mutating func ingest(_ byte: UInt8) throws {
        if byte == 0x0A {
            try finishPendingLine()
            return
        }
        pendingData.append(byte)
    }

    mutating func finish() throws {
        try finishPendingLine()
    }

    var collectedText: String {
        collectedChunks.joined()
    }

    private mutating func finishPendingLine() throws {
        guard !pendingData.isEmpty else { return }
        try processLine(pendingData)
        pendingData.removeAll(keepingCapacity: true)
    }

    private mutating func processLine(_ data: Data) throws {
        let trimmedLine = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return }
        guard trimmedLine.hasPrefix("data:") else { return }

        let payload = trimmedLine.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]" else { return }

        let payloadData = Data(payload.utf8)
        do {
            let event = try CodexStreamEvent.parse(from: payloadData)
            try handleEvent?(event)
            let text = extractText(event)
            if !text.isEmpty {
                collectedChunks.append(text)
            }
        } catch {
            throw CodexStructuredToolError.malformedStreamEvent(String(payload))
        }
    }
}

private struct CodexIntentAccumulator {
    private var orderedKeys: [String] = []
    private var toolCalls: [String: CodexStreamToolCall] = [:]

    mutating func ingest(_ event: CodexStreamEvent) {
        for fragment in event.toolCalls ?? [] {
            ingest(fragment)
        }
    }

    mutating func ingest(_ fragment: CodexStreamToolCall) {
        let key = fragment.identityKey
        if let existing = toolCalls[key] {
            toolCalls[key] = existing.merged(with: fragment)
        } else {
            orderedKeys.append(key)
            toolCalls[key] = fragment
        }
    }

    func finalizedAction() throws -> CodexAction? {
        for key in orderedKeys {
            guard let call = toolCalls[key] else { continue }
            guard let name = call.name, !name.isEmpty else { continue }
            guard let arguments = call.arguments, !arguments.isEmpty else { continue }
            return .callTool(name: name, arguments: try decodeToolArguments(arguments))
        }
        return nil
    }

    private func decodeToolArguments(_ raw: String) throws -> [String: Any] {
        let normalized = normalizedCodexStructuredText(raw)
        guard let data = normalized.data(using: .utf8) else {
            throw CodexStructuredToolError.malformedToolArguments(raw)
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dictionary = object as? [String: Any] else {
                throw CodexStructuredToolError.malformedToolArguments(raw)
            }
            return dictionary
        } catch let error as CodexStructuredToolError {
            throw error
        } catch {
            throw CodexStructuredToolError.malformedToolArguments(raw)
        }
    }
}
