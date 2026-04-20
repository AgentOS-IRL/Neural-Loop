import XCTest
@testable import CodexCore

private enum CodexStructuredToolTestFixtures {
    static let defaultIntentInstructions = NeuralLoopCodexIntents.getDefaultIntentInstructions(currentDateISO: "2026-04-20T12:00:00Z")

    static var defaultIntentTools: [CodexTool] {
        [
            createTaskTool,
            createSubTaskTool,
            notesTool
        ]
    }

    static let createTaskTool = CodexTool(
        name: "create_task",
        description: "Create a to-do item when the user wants to add a task. Include start_date when the user mentions a date, time, morning, afternoon, or evening. Use an ISO-8601 string when possible. If only a date is known, assume afternoon and mention that assumption in description. If start_date is present and duration is omitted, the app defaults duration to 900 seconds.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object(["type": .string("string")]),
                "description": .object(["type": .string("string")]),
                "start_date": .object(["type": .string("string")]),
                "duration": .object(["type": .string("number")])
            ]),
            "required": .array([.string("title")])
        ])
    )

    static let createSubTaskTool = CodexTool(
        name: "create_sub_task",
        description: "Create a subtask for an existing to-do. Only use this when the parent task is already known. Require task_id and title, trim whitespace before saving, and ask for clarification if the parent task is missing or ambiguous. It is valid to call this repeatedly for the same parent task once that parent is established, including to add grocery-item subtasks under an existing grocery list.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "task_id": .object([
                    "type": .string("number")
                ]),
                "title": .object([
                    "type": .string("string")
                ])
            ]),
            "required": .array([
                .string("task_id"),
                .string("title")
            ])
        ])
    )

    static let notesTool = CodexTool(
        name: "Notes",
        description: "Create a fleeting note.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "content": .object(["type": .string("string")])
            ]),
            "required": .array([.string("content")])
        ])
    )
}

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
        XCTAssertEqual(tool.model, "gpt-5.4-mini")
        XCTAssertEqual(tool.instructions, "You are a helpful assistant.")
        XCTAssertEqual(tool.timeout, 60)
    }

    func testDefaultIntentInstructionsDescribeGroceryWorkflow() {
        let instructions = CodexStructuredToolTestFixtures.defaultIntentInstructions

        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("grocery list"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("shopping list"))
        XCTAssertTrue(instructions.contains("create_task"))
        XCTAssertTrue(instructions.contains("create_sub_task"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("parent task id"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("same response"))
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

        XCTAssertEqual(body.model, "gpt-5.4-mini")
        XCTAssertTrue(body.stream)
        XCTAssertFalse(body.store)
        XCTAssertEqual(body.instructions, "You are a helpful assistant.")
        XCTAssertEqual(body.text.verbosity, "medium")
        XCTAssertNil(body.text.format)
        XCTAssertNil(body.tools)
        XCTAssertNil(body.tool_choice)
        XCTAssertEqual(body.input.first?.role, "user")
        XCTAssertEqual(body.input.first?.content.first?.type, "input_text")
        XCTAssertEqual(body.input.first?.content.first?.text, "Write a haiku")

        let encoded = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-5.4-mini")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["store"] as? Bool, false)
    }

    func testCodexToolEncodesOpenAICompatibleFunctionPayload() throws {
        let tool = CodexTool(
            name: "create_task",
            description: "Create a to-do item.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string")
                    ]),
                    "description": .object([
                        "type": .string("string")
                    ]),
                    "start_date": .object([
                        "type": .string("string")
                    ]),
                    "duration": .object([
                        "type": .string("number")
                    ])
                ]),
                "required": .array([
                    .string("title")
                ])
            ])
        )

        let encoded = try JSONEncoder().encode(tool)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "function")
        XCTAssertEqual(json["name"] as? String, "create_task")
        XCTAssertEqual(json["description"] as? String, "Create a to-do item.")

        let parameters = try XCTUnwrap(json["parameters"] as? [String: Any])
        XCTAssertEqual(parameters["type"] as? String, "object")
        XCTAssertEqual(parameters["required"] as? [String], ["title"])

        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        XCTAssertNotNil(properties["start_date"])
        XCTAssertNotNil(properties["duration"])
    }

    func testCodexToolEncodesSubTaskPayload() throws {
        let encoded = try JSONEncoder().encode(CodexStructuredToolTestFixtures.createSubTaskTool)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "function")
        XCTAssertEqual(json["name"] as? String, "create_sub_task")

        let parameters = try XCTUnwrap(json["parameters"] as? [String: Any])
        XCTAssertEqual(parameters["type"] as? String, "object")
        XCTAssertEqual(parameters["required"] as? [String], ["task_id", "title"])

        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        XCTAssertNotNil(properties["task_id"])
        XCTAssertNotNil(properties["title"])
    }

    func testIntentRequestIncludesToolDefinitionsAndAutoChoice() async throws {
        var capturedRequests: [URLRequest] = []

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { request in
                capturedRequests.append(request)
                return [
                    "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"text\":\"Which task do you want me to create?\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [
                CodexInputMessage(
                    role: "user",
                    content: [CodexInputContent(type: "input_text", text: "make something")]
                )
            ],
            state: CodexConversationState(previousResponseID: "resp_prev"),
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        guard case .clarify(let text) = result.action else {
            return XCTFail("Expected clarification response")
        }
        XCTAssertEqual(text, "Which task do you want me to create?")
        XCTAssertEqual(result.state.previousResponseID, "resp_prev")

        let request = try XCTUnwrap(capturedRequests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["instructions"] as? String, CodexStructuredToolTestFixtures.defaultIntentInstructions)
        XCTAssertEqual(json["tool_choice"] as? String, "auto")
        XCTAssertEqual(json["parallel_tool_calls"] as? Bool, false)
        XCTAssertEqual(json["store"] as? Bool, false)
        XCTAssertNil(json["previous_response_id"])

        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 3)
        XCTAssertEqual(tools[0]["name"] as? String, "create_task")
        XCTAssertEqual(tools[1]["name"] as? String, "create_sub_task")
        XCTAssertEqual(tools[2]["name"] as? String, "Notes")
    }

    func testStatefulConverseCapturesLatestResponseID() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_new\",\"output\":[{\"content\":[{\"text\":\"What would you like me to do?\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [
                CodexInputMessage(
                    role: "user",
                    content: [CodexInputContent(type: "input_text", text: "something vague")]
                )
            ],
            state: CodexConversationState(previousResponseID: "resp_old", conversationID: "conv_1"),
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )

        guard case .clarify(let text) = result.action else {
            return XCTFail("Expected clarification")
        }

        XCTAssertEqual(text, "What would you like me to do?")
        XCTAssertEqual(result.state.previousResponseID, "resp_new")
        XCTAssertEqual(result.state.conversationID, "conv_1")
    }

    func testConverseReturnsToolCallFromChunkedArguments() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"index\":0,\"function\":{\"name\":\"create_task\",\"arguments\":\"{\\\"title\\\":\\\"Buy \"}}]}}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"index\":0,\"function\":{\"arguments\":\"milk\\\",\\\"description\\\":\\\"From the store\\\"}\"}}]}}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("remind me")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        let action = result.action
        guard case .callTool(let name, let arguments) = action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "create_task")
        XCTAssertEqual(arguments["title"] as? String, "Buy milk")
        XCTAssertEqual(arguments["description"] as? String, "From the store")
    }

    func testConverseReturnsSubTaskToolCallFromChunkedArguments() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"index\":0,\"function\":{\"name\":\"create_sub_task\",\"arguments\":\"{\\\"task_id\\\":42,\\\"title\\\":\\\"Draft \"}}]}}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"index\":0,\"function\":{\"arguments\":\"outline\\\"}\"}}]}}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("add a subtask")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )

        guard case .callTool(let name, let arguments) = result.action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "create_sub_task")
        XCTAssertEqual(arguments["task_id"] as? Int, 42)
        XCTAssertEqual(arguments["title"] as? String, "Draft outline")
    }

    func testConverseReturnsToolCallWithOptionalSchedulingArguments() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.output_item.added\",\"output_index\":0,\"item\":{\"type\":\"function_call\",\"id\":\"call_1\",\"name\":\"create_task\",\"arguments\":\"{\\\"title\\\":\\\"Call dentist\\\",\\\"description\\\":\\\"Defaulted to afternoon\\\",\\\"start_date\\\":\\\"2026-04-20\\\",\\\"duration\\\":900}\"}}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("schedule a call")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        guard case .callTool(let name, let arguments) = result.action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "create_task")
        XCTAssertEqual(arguments["title"] as? String, "Call dentist")
        XCTAssertEqual(arguments["description"] as? String, "Defaulted to afternoon")
        XCTAssertEqual(arguments["start_date"] as? String, "2026-04-20")
        XCTAssertEqual(arguments["duration"] as? Int, 900)
    }

    func testConverseReturnsToolCallFromOutputItemAddedEvent() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.output_item.added\",\"output_index\":0,\"item\":{\"type\":\"function_call\",\"id\":\"call_1\",\"name\":\"Notes\",\"arguments\":\"{\\\"content\\\":\\\"Remember the keys\\\"}\"}}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("save this")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        let action = result.action
        guard case .callTool(let name, let arguments) = action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "Notes")
        XCTAssertEqual(arguments["content"] as? String, "Remember the keys")
    }

    func testConverseUsesFinalArgumentsInsteadOfAppendingThemTwice() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.output_item.added\",\"output_index\":0,\"item\":{\"type\":\"function_call\",\"id\":\"call_1\",\"name\":\"create_task\",\"arguments\":\"\"}}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.function_call_arguments.delta\",\"item_id\":\"call_1\",\"output_index\":0,\"delta\":\"{\\\"title\\\":\\\"Buy \"}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.function_call_arguments.delta\",\"item_id\":\"call_1\",\"output_index\":0,\"delta\":\"milk\\\",\\\"description\\\":\\\"From the store\\\"}\"}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.function_call_arguments.done\",\"item_id\":\"call_1\",\"output_index\":0,\"arguments\":\"{\\\"title\\\":\\\"Buy milk\\\",\\\"description\\\":\\\"From the store\\\"}\"}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("remind me")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        let action = result.action
        guard case .callTool(let name, let arguments) = action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "create_task")
        XCTAssertEqual(arguments["title"] as? String, "Buy milk")
        XCTAssertEqual(arguments["description"] as? String, "From the store")
    }

    func testConverseNormalizesFencedToolArguments() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"index\":0,\"function\":{\"name\":\"Notes\",\"arguments\":\"```json\\n{\\\"content\\\":\\\"Remember the keys\\\"}\\n```\"}}]}}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("save this")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        let action = result.action
        guard case .callTool(let name, let arguments) = action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "Notes")
        XCTAssertEqual(arguments["content"] as? String, "Remember the keys")
    }

    func testConverseFallsBackToClarificationWhenNoToolCallIsEmitted() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"text\":\"What would you like me to do?\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("something vague")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )
        let action = result.action
        guard case .clarify(let text) = action else {
            return XCTFail("Expected clarification")
        }

        XCTAssertEqual(text, "What would you like me to do?")
    }

    func testConverseFallsBackToClarificationWhenSubtaskParentContextIsMissing() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"text\":\"Which task should this subtask belong to?\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("add a subtask")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )

        guard case .clarify(let text) = result.action else {
            return XCTFail("Expected clarification")
        }

        XCTAssertEqual(text, "Which task should this subtask belong to?")
    }

    func testConverseClarifiesWhenGroceryListHasNoItems() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"content\":[{\"text\":\"What grocery items should I add?\"}]}]}}\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("make me a grocery list")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )

        guard case .clarify(let text) = result.action else {
            return XCTFail("Expected clarification")
        }

        XCTAssertEqual(text, "What grocery items should I add?")
    }

    func testConverseReturnsParentTaskToolCallForGroceryRequest() async throws {
        let streamPayload = """
        {"type":"response.output_text.delta","delta":{"tool_calls":[{"id":"call_parent","index":0,"function":{"name":"create_task","arguments":"{\\"title\\":\\"Grocery list\\",\\"description\\":\\"Milk and eggs\\"}"}}]}}
        """

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    "data: \(streamPayload)\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexStructuredTool.userMessage("make a grocery list for milk and eggs")],
            tools: CodexStructuredToolTestFixtures.defaultIntentTools,
            instructions: CodexStructuredToolTestFixtures.defaultIntentInstructions
        )

        guard case .callTool(let name, let arguments) = result.action else {
            return XCTFail("Expected tool call")
        }

        XCTAssertEqual(name, "create_task")
        XCTAssertEqual(arguments["title"] as? String, "Grocery list")
        XCTAssertEqual(arguments["description"] as? String, "Milk and eggs")

        let event = try CodexStreamEvent.parse(from: Data(streamPayload.utf8))
        XCTAssertEqual(event.toolCalls?.compactMap(\.name), ["create_task"])
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

    func testStreamingCollectorConcatenatesChunksAndSkipsDonePayloads() async throws {
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

        let result = try await tool.invoke("hello world")
        XCTAssertEqual(result, "Hello!")
        XCTAssertEqual(capturedRequests.count, 1)
    }

    func testStructuredOutputParsesDecodedTypeAndKeepsRawPayload() async throws {
        struct ExampleResponse: Codable, Equatable {
            let name: String
            let count: Int
        }

        struct ExampleSchema: CodexSchemaProviding {
            static var codexSchemaPayload: CodexJSONSchemaPayload {
                CodexJSONSchemaPayload(
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

        let result = try await tool.invokeStructuredWithRaw(
            "Give me a structured response",
            as: ExampleResponse.self,
            method: .jsonMode,
            schema: ExampleSchema.codexSchemaPayload
        )

        XCTAssertEqual(capturedRequests.count, 1)
        XCTAssertEqual(result.raw, "Here is the answer:```json\n{\"name\":\"Ada\",\"count\":2}\n```")
        XCTAssertEqual(result.parsed, ExampleResponse(name: "Ada", count: 2))
    }

    func testFunctionCallingModeOmitsTextFormatAndStillDecodesJSON() async throws {
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

        let parsed = try await tool.invokeStructured(
            "Return one field",
            as: ExampleResponse.self,
            method: .functionCalling
        )

        XCTAssertEqual(capturedRequests.count, 1)
        XCTAssertEqual(parsed, ExampleResponse(name: "Grace"))
    }

    func testNetworkPathStreamsChunksThroughMockProtocol() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockStreamingURLProtocol.self]

        MockStreamingURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return .init(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Hel\"}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":\"lo\"}\n".data(using: .utf8)!,
                    "data: {\"type\":\"response.output_text.done\",\"response\":{\"output\":[{\"content\":[{\"text\":\"!\"}]}]}}\n".data(using: .utf8)!,
                    "data: [DONE]\n".data(using: .utf8)!
                ]
            )
        }

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            sessionConfiguration: configuration
        )

        let result = try await tool.invoke("hello")
        XCTAssertEqual(result, "Hello!")
        XCTAssertEqual(MockStreamingURLProtocol.capturedRequests.count, 1)
    }

    func testNetworkPathFailsWhenResponseIsNotSSE() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockStreamingURLProtocol.self]

        MockStreamingURLProtocol.requestHandler = { _ in
            .init(
                statusCode: 500,
                headers: ["Content-Type": "application/json"],
                chunks: [
                    #"{"error":"server failure"}"#.data(using: .utf8)!
                ]
            )
        }

        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            sessionConfiguration: configuration
        )

        do {
            _ = try await tool.invoke("hello")
            XCTFail("Expected transport error")
        } catch let error as CodexStructuredToolError {
            guard case .transport(let message) = error else {
                XCTFail("Expected transport error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("HTTP 500") || message.contains("event-stream"))
        } catch {
            XCTFail("Expected CodexStructuredToolError, got \(error)")
        }
    }
}
