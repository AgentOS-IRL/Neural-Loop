import XCTest
@testable import CodexCore

final class ConfigBehaviorTests: XCTestCase {
    func testInitializerAppliesDefaults() {
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account"
        )

        XCTAssertEqual(tool.baseURL.absoluteString, "https://chatgpt.com/backend-api/codex/responses")
        XCTAssertEqual(tool.model, "gpt-5.4-mini")
        XCTAssertEqual(tool.instructions, "You are a helpful assistant.")
        XCTAssertEqual(tool.timeout, 60)
        XCTAssertEqual(tool.sessionConfiguration.timeoutIntervalForRequest, 60)
        XCTAssertEqual(tool.sessionConfiguration.timeoutIntervalForResource, 60)
    }

    func testInitializerHonorsExplicitOverrides() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/codex"))
        let tool = CodexStructuredTool(
            access_token: "token",
            account_id: "account",
            model: "gpt-5.4",
            url: url,
            instructions: "Custom instructions",
            timeout: 12
        )

        XCTAssertEqual(tool.baseURL, url)
        XCTAssertEqual(tool.model, "gpt-5.4")
        XCTAssertEqual(tool.instructions, "Custom instructions")
        XCTAssertEqual(tool.timeout, 12)
        XCTAssertEqual(tool.sessionConfiguration.timeoutIntervalForRequest, 12)
        XCTAssertEqual(tool.sessionConfiguration.timeoutIntervalForResource, 12)
    }

    func testStrictFlagAddsAdditionalPropertiesToObjectSchemasOnly() {
        let objectSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string")
                ])
            ])
        ])

        let strictObjectSchema = objectSchema.applyingStrictFlag(true)
        let passthroughObjectSchema = objectSchema.applyingStrictFlag(false)

        let arraySchema: JSONValue = .array([
            .string("value")
        ])

        XCTAssertEqual(passthroughObjectSchema, objectSchema)

        guard case .object(let strictObjectDictionary) = strictObjectSchema else {
            return XCTFail("Expected strict object schema")
        }
        XCTAssertEqual(strictObjectDictionary["additionalProperties"], .bool(false))

        XCTAssertEqual(arraySchema.applyingStrictFlag(true), arraySchema)
    }

    func testStructuredErrorDescriptionsStayReadable() {
        XCTAssertEqual(
            CodexStructuredToolError.invalidURL.errorDescription,
            "CodexStructuredTool was configured with an invalid URL."
        )
        XCTAssertEqual(
            CodexStructuredToolError.missingSchemaPayload.errorDescription,
            "No JSON schema payload was provided for jsonSchema mode."
        )
        XCTAssertEqual(
            CodexStructuredToolError.transport("boom").errorDescription,
            "Codex transport error: boom"
        )
    }
}
