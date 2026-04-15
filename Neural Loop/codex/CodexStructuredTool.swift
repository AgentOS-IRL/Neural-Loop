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

public protocol CodexSchemaProviding {
    static var codexSchemaPayload: CodexJSONSchemaPayload { get }
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
        self.model = model ?? "gpt-5.1-codex"
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
        text_format: JSONValue? = nil
    ) -> CodexRequestBody {
        CodexRequestBody(
            model: model,
            stream: true,
            store: false,
            instructions: instructions ?? self.instructions,
            text: CodexTextConfig(verbosity: "medium", format: text_format),
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
        text_format: JSONValue?
    ) async throws -> String {
        let request = try _build_request(
            prompt: prompt,
            url: url,
            instructions: instructions,
            text_format: text_format
        )

        if let streamingChunksProvider {
            do {
                let chunks = try await streamingChunksProvider(request)
                return try collectText(
                    from: chunks,
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
            try validate(response: response)
            return try await collectText(
                from: bytes,
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
        text_format: JSONValue? = nil
    ) throws -> URLRequest {
        let requestURL = url ?? baseURL

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout

        let headers = _build_headers()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body = _build_body(prompt: prompt, instructions: instructions, text_format: text_format)
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
        let normalized = normalizedStructuredText(raw)
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
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fenced = extractFirstCodeFence(in: trimmed) {
            return fenced.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let candidates: [(Character, Character)] = [("{", "}"), ("[", "]")]
        for (open, close) in candidates {
            if let range = extractBalancedJSONRange(in: trimmed, opening: open, closing: close) {
                return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }

    private func extractFirstCodeFence(in text: String) -> String? {
        guard let start = text.range(of: "```") else { return nil }
        let remainder = text[start.upperBound...]
        guard let end = remainder.range(of: "```") else { return nil }
        var content = String(remainder[..<end.lowerBound])
        if let firstNewline = content.firstIndex(of: "\n") {
            let prefix = content[..<firstNewline]
            if prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("json") {
                content = String(content[content.index(after: firstNewline)...])
            }
        }
        return content
    }

    private func extractBalancedJSONRange(in text: String, opening: Character, closing: Character) -> Range<String.Index>? {
        guard let start = text.firstIndex(of: opening), let end = text.lastIndex(of: closing), start < end else {
            return nil
        }
        return start..<text.index(after: end)
    }

    private func validate(response: URLResponse) throws {
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
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

    private func collectText(
        from chunks: [Data],
        extractText: @escaping (CodexStreamEvent) -> String
    ) throws -> String {
        var collector = CodexSSECollector(extractText: extractText)
        for chunk in chunks {
            try collector.ingest(chunk)
        }
        try collector.finish()
        return collector.collectedText
    }

    private func collectText(
        from bytes: URLSession.AsyncBytes,
        extractText: @escaping (CodexStreamEvent) -> String
    ) async throws -> String {
        var collector = CodexSSECollector(extractText: extractText)
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
    public let response: CodexStreamResponse?

    static func parse(from data: Data) throws -> CodexStreamEvent {
        let payload = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = payload as? [String: Any], let type = dictionary["type"] as? String else {
            throw CodexStructuredToolError.malformedStreamEvent(String(decoding: data, as: UTF8.self))
        }

        let delta = dictionary["delta"] as? String
        let response = try CodexStreamResponse.parse(dictionary["response"])
        return CodexStreamEvent(type: type, delta: delta, response: response)
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
    private var pendingData = Data()
    private(set) var collectedChunks: [String] = []

    init(extractText: @escaping (CodexStreamEvent) -> String) {
        self.extractText = extractText
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
            let text = extractText(event)
            if !text.isEmpty {
                collectedChunks.append(text)
            }
        } catch {
            throw CodexStructuredToolError.malformedStreamEvent(String(payload))
        }
    }
}
