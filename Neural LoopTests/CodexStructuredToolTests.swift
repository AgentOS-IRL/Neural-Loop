import XCTest
@testable import Neural_Loop

final class CodexStructuredToolTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockStreamingURLProtocol.reset()
    }

    override func tearDown() {
        MockStreamingURLProtocol.reset()
        super.tearDown()
    }

    func testDefaultsAreAppliedWhenOptionalValuesAreOmitted() {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account"
        )

        XCTAssertEqual(tool.baseURL.absoluteString, "https://chatgpt.com/backend-api/codex/responses")
        XCTAssertEqual(tool.model, "gpt-5.1-codex")
        XCTAssertEqual(tool.instructions, "You are a helpful assistant.")
        XCTAssertEqual(tool.timeout, 60)
    }

    func testBuildHeadersIncludeCodexFieldsAndUniqueSessionId() {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account"
        )

        let first = tool._build_headers()
        let second = tool._build_headers()

        XCTAssertEqual(first["Authorization"], "Bearer token")
        XCTAssertEqual(first["chatgpt-account-id"], "account")
        XCTAssertEqual(first["OpenAI-Beta"], "responses=experimental")
        XCTAssertEqual(first["originator"], "codex_cli_rs")
        XCTAssertEqual(first["accept"], "text/event-stream")
        XCTAssertEqual(first["content-type"], "application/json")
        XCTAssertEqual(first["User-Agent"], "python-codex-client/1.0")
        XCTAssertNotNil(first["session_id"])
        XCTAssertNotEqual(first["session_id"], second["session_id"])
    }

    func testBuildBodyProducesExpectedRawRequestShape() throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account"
        )

        let body = tool._build_body(
            prompt: "Write a haiku",
            instructions: nil,
            text_format: nil
        )

        XCTAssertEqual(body.model, "gpt-5.1-codex")
        XCTAssertTrue(body.stream)
        XCTAssertFalse(body.store)
        XCTAssertEqual(body.instructions, "You are a helpful assistant.")
        XCTAssertEqual(body.text.verbosity, "medium")
        XCTAssertNil(body.text.format)
        XCTAssertEqual(body.input.first?.role, "user")
        XCTAssertEqual(body.input.first?.content.first?.type, "input_text")
        XCTAssertEqual(body.input.first?.content.first?.text, "Write a haiku")

        let encoded = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-5.1-codex")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["store"] as? Bool, false)
    }

    func testBuildBodyProducesStructuredFormat() throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account"
        )

        let format: JSONValue = .object([
            "type": .string("json_schema"),
            "name": .string("Example"),
            "strict": .bool(true),
            "schema": .object([
                "type": .string("object")
            ])
        ])

        let body = tool._build_body(
            prompt: "Return the payload",
            instructions: "Custom instructions",
            text_format: format
        )

        XCTAssertEqual(body.instructions, "Custom instructions")
        XCTAssertEqual(body.text.format, format)
    }

    func testExtractTextFromEventHandlesDeltaDoneCompletedAndIgnoredEvents() {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account"
        )

        let deltaEvent = CodexStreamEvent(
            type: "response.output_text.delta",
            delta: "hel",
            response: nil
        )
        let doneEvent = CodexStreamEvent(
            type: "response.output_text.done",
            delta: nil,
            response: CodexStreamResponse(
                output: [
                    CodexStreamOutput(
                        content: [
                            CodexStreamContent(text: "lo")
                        ]
                    )
                ]
            )
        )
        let completedEvent = CodexStreamEvent(
            type: "response.completed",
            delta: nil,
            response: CodexStreamResponse(
                output: [
                    CodexStreamOutput(
                        content: [
                            CodexStreamContent(text: " world")
                        ]
                    )
                ]
            )
        )
        let ignoredEvent = CodexStreamEvent(
            type: "response.some_other_event",
            delta: "ignored",
            response: nil
        )

        XCTAssertEqual(tool._extract_text_from_event(deltaEvent), "hel")
        XCTAssertEqual(tool._extract_text_from_event(doneEvent), "lo")
        XCTAssertEqual(tool._extract_text_from_event(completedEvent), " world")
        XCTAssertEqual(tool._extract_text_from_event(ignoredEvent), "")
    }

    func testStreamingCollectorConcatenatesChunksAndSkipsDonePayloads() throws {
        var capturedRequests: [URLRequest] = []

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { request in
                capturedRequests.append(request)
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")

                return [
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Hel".data(using: .utf8)!,
                    "lo\"}\n".data(using: .utf8)!,
                    "data:\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.output_text.done\",\"response\":{\"output\":[{\"content\":[{\"text\":\"!\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try tool.executeSync("hello world")
        XCTAssertEqual(result, "Hello!")
        XCTAssertEqual(capturedRequests.count, 1)
    }

    func testStructuredOutputParsesDecodedTypeAndKeepsRawPayload() throws {
        struct ExampleResponse: Codable, Equatable {
            let name: String
            let count: Int
        }

        struct ExampleSchema: CodexSchemaProviding {
            static let codexSchemaPayload = CodexJSONSchemaPayload(
                name: "ExampleResponse",
                schema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "name": .object([
                            "type": .string("string")
                        ]),
                        "count": .object([
                            "type": .string("integer")
                        ])
                    ])
                ])
            )
        }

        var capturedRequests: [URLRequest] = []

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { request in
                capturedRequests.append(request)

                return [
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Here is the answer:\"}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"text\":\"```json\\n{\\\"name\\\":\\\"Ada\\\",\\\"count\\\":2}\\n```\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try tool.executeStructuredWithRaw(
            "Give me a structured response",
            as: ExampleResponse.self,
            method: .jsonMode,
            schema: ExampleSchema.codexSchemaPayload
        )

        XCTAssertEqual(capturedRequests.count, 1)
        XCTAssertEqual(result.raw, "Here is the answer:```json\n{\"name\":\"Ada\",\"count\":2}\n```")
        XCTAssertEqual(result.parsed, ExampleResponse(name: "Ada", count: 2))
    }

    func testFunctionCallingModeOmitsTextFormatAndStillDecodesJSON() throws {
        struct ExampleResponse: Codable, Equatable {
            let name: String
        }

        var capturedRequests: [URLRequest] = []

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { request in
                capturedRequests.append(request)

                return [
                    "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"text\":\"{\\\"name\\\":\\\"Grace\\\"}\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let parsed = try tool.executeStructured(
            "Return one field",
            as: ExampleResponse.self,
            method: .functionCalling
        )

        XCTAssertEqual(capturedRequests.count, 1)
        XCTAssertEqual(parsed, ExampleResponse(name: "Grace"))
    }
}
