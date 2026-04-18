import XCTest
@testable import CodexCore

final class LangChainBehaviorTests: XCTestCase {
    func testConverseFallsBackToClarificationWhenToolArgumentsAreMalformed() async throws {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            streamingChunksProvider: { _ in
                [
                    (#"data: {"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","id":"call_1","name":"Notes","arguments":"{"}}"# + "\n").data(using: .utf8)!,
                    (#"data: {"type":"response.completed","response":{"output":[{"content":[{"text":"Need more detail."}]}]}}"# + "\n").data(using: .utf8)!,
                    (#"data: [DONE]"# + "\n").data(using: .utf8)!
                ]
            }
        )

        let result = try await tool.converse(
            messages: [CodexInputMessage(role: "user", content: [CodexInputContent(type: "input_text", text: "save this")])],
            tools: [
                CodexTool(
                    name: "Notes",
                    description: "Create a fleeting note.",
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
            ],
            instructions: "Use the Notes tool when appropriate."
        )

        guard case .clarify(let text) = result.action else {
            return XCTFail("Expected clarification when tool arguments cannot be decoded")
        }

        XCTAssertEqual(text, "Need more detail.")
    }

    func testStreamEventParseExtractsNestedToolCallFromResponsesPayload() throws {
        let data = #"{"type":"response.output_text.delta","delta":{"tool_calls":[{"id":"call_1","index":0,"function":{"name":"Notes","arguments":"{\"content\":\"Remember the keys\"}"}}]}}"#.data(using: .utf8)!

        let event = try CodexStreamEvent.parse(from: data)

        XCTAssertEqual(event.type, "response.output_text.delta")
        XCTAssertEqual(event.toolCalls?.count, 1)
        XCTAssertEqual(event.toolCalls?.first?.id, "call_1")
        XCTAssertEqual(event.toolCalls?.first?.index, 0)
        XCTAssertEqual(event.toolCalls?.first?.name, "Notes")
        XCTAssertEqual(event.toolCalls?.first?.arguments, #"{"content":"Remember the keys"}"#)
        XCTAssertFalse(event.toolCalls?.first?.argumentsFinal ?? true)
    }

    func testStreamEventParseRejectsPayloadWithoutType() {
        let data = #"{"delta":"ignored"}"#.data(using: .utf8)!

        do {
            _ = try CodexStreamEvent.parse(from: data)
            XCTFail("Expected malformed stream event error")
        } catch let error as CodexStructuredToolError {
            guard case .malformedStreamEvent(let payload) = error else {
                return XCTFail("Expected malformed stream event error, got \(error)")
            }
            XCTAssertEqual(payload, #"{"delta":"ignored"}"#)
        } catch {
            XCTFail("Expected CodexStructuredToolError, got \(error)")
        }
    }

    func testStreamEventParseHandlesResponseCompletedWithoutToolCalls() throws {
        let data = #"{"type":"response.completed","response":{"output":[{"content":[{"text":"Need more detail."}]}]}}"#.data(using: .utf8)!

        let event = try CodexStreamEvent.parse(from: data)

        XCTAssertEqual(event.type, "response.completed")
        XCTAssertEqual(event.response?.output?.first?.content?.first?.text, "Need more detail.")
        XCTAssertNil(event.toolCalls)
    }
}
