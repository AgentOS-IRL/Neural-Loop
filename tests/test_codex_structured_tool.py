from __future__ import annotations

import json

import pytest
from pydantic import BaseModel

from codex_client.structured_tool import CodexStructuredTool


class FakeTransport:
    def __init__(self, lines: list[str]) -> None:
        self.lines = lines
        self.calls: list[tuple[str, dict[str, str], bytes, float]] = []

    def __call__(self, url: str, headers: dict[str, str], body: bytes, timeout: float):
        self.calls.append((url, headers, body, timeout))
        return list(self.lines)


class SampleSchema(BaseModel):
    message: str
    count: int


def test_build_headers_contains_required_values():
    tool = CodexStructuredTool(
        access_token="token-123",
        account_id="acct-456",
        session_id_factory=lambda: "session-789",
    )

    assert tool._build_headers() == {
        "Authorization": "Bearer token-123",
        "chatgpt-account-id": "acct-456",
        "OpenAI-Beta": "responses=experimental",
        "originator": "codex_cli_rs",
        "session_id": "session-789",
        "accept": "text/event-stream",
        "content-type": "application/json",
        "User-Agent": "python-codex-client/1.0",
    }


def test_build_body_uses_requested_defaults_and_overrides():
    tool = CodexStructuredTool(
        access_token="token-123",
        account_id="acct-456",
        model="gpt-custom",
        instructions="Custom instructions.",
    )

    body = tool._build_body(
        "Write a haiku.",
        text_format={"type": "json_object"},
    )

    assert body["model"] == "gpt-custom"
    assert body["stream"] is True
    assert body["store"] is False
    assert body["instructions"] == "Custom instructions."
    assert body["text"]["verbosity"] == "medium"
    assert body["text"]["format"] == {"type": "json_object"}
    assert body["input"] == [
        {
            "role": "user",
            "content": [
                {
                    "type": "input_text",
                    "text": "Write a haiku.",
                }
            ],
        }
    ]


def test_extract_text_from_event_handles_delta_and_done_payloads():
    tool = CodexStructuredTool(access_token="token", account_id="acct")

    assert tool._extract_text_from_event({"type": "response.output_text.delta", "delta": "hello"}) == "hello"
    assert tool._extract_text_from_event({"type": "response.output_text.delta", "delta": 42}) == "42"
    assert tool._extract_text_from_event({"type": "response.output_text.done", "response": {"output": [{"content": [{"text": "a"}, {"text": "b"}]}]}}) == "ab"
    assert tool._extract_text_from_event({"type": "response.completed", "response": {"output": [{"content": [{"text": "x"}]}, {"content": [{"text": "y"}]}]}}) == "xy"
    assert tool._extract_text_from_event({"type": "ignored"}) == ""


def test_execute_sync_collects_streaming_text_and_stops_on_done():
    transport = FakeTransport(
        [
            'data: {"type":"response.output_text.delta","delta":"Hello"}\n',
            "data: [DONE]\n",
            'data: {"type":"response.output_text.delta","delta":" ignored"}\n',
        ]
    )
    tool = CodexStructuredTool(
        access_token="token-123",
        account_id="acct-456",
        transport=transport,
        session_id_factory=lambda: "session-789",
    )

    result = tool.execute_sync("Say hello.", url="https://example.com/custom")

    assert result == "Hello"
    assert len(transport.calls) == 1
    url, headers, body, timeout = transport.calls[0]
    assert url == "https://example.com/custom"
    assert headers["Authorization"] == "Bearer token-123"
    assert timeout == 60

    decoded = json.loads(body.decode("utf-8"))
    assert decoded["instructions"] == "You are a helpful assistant."
    assert decoded["input"][0]["content"][0]["text"] == "Say hello."


def test_execute_structured_json_schema_builds_schema_payload_and_parses_result():
    transport = FakeTransport(
        ['data: {"type":"response.output_text.delta","delta":"{\\"message\\":\\"hi\\",\\"count\\":3}"}\n']
    )
    tool = CodexStructuredTool(
        access_token="token-123",
        account_id="acct-456",
        transport=transport,
        session_id_factory=lambda: "session-789",
    )

    parsed = tool.execute_structured("Return a sample.", SampleSchema, strict=True)

    assert isinstance(parsed, SampleSchema)
    assert parsed.message == "hi"
    assert parsed.count == 3

    body = json.loads(transport.calls[0][2].decode("utf-8"))
    assert body["text"]["format"]["type"] == "json_schema"
    assert body["text"]["format"]["name"] == "SampleSchema"
    assert body["text"]["format"]["strict"] is True
    assert body["text"]["format"]["schema"]["additionalProperties"] is False


def test_execute_structured_json_mode_appends_parser_instructions_and_can_include_raw():
    transport = FakeTransport(
        ['data: {"type":"response.output_text.delta","delta":"{\\"message\\":\\"json mode\\",\\"count\\":7}"}\n']
    )
    tool = CodexStructuredTool(
        access_token="token-123",
        account_id="acct-456",
        transport=transport,
        session_id_factory=lambda: "session-789",
    )

    result = tool.execute_structured("Return a sample.", SampleSchema, method="json_mode", include_raw=True)

    assert result["raw"] == '{"message":"json mode","count":7}'
    assert result["parsed"].message == "json mode"
    assert result["parsed"].count == 7

    body = json.loads(transport.calls[0][2].decode("utf-8"))
    prompt = body["input"][0]["content"][0]["text"]
    assert "Return only JSON." in prompt
    assert "The JSON should match the schema fields" in prompt
    assert body["text"]["format"] == {"type": "json_object"}


def test_execute_structured_function_calling_uses_parser_instructions_without_text_format():
    transport = FakeTransport(
        ['data: {"type":"response.output_text.delta","delta":"{\\"message\\":\\"function\\",\\"count\\":11}"}\n']
    )
    tool = CodexStructuredTool(
        access_token="token-123",
        account_id="acct-456",
        transport=transport,
        session_id_factory=lambda: "session-789",
    )

    parsed = tool.execute_structured("Return a sample.", SampleSchema, method="function_calling")

    assert parsed.message == "function"
    assert parsed.count == 11

    body = json.loads(transport.calls[0][2].decode("utf-8"))
    assert "format" not in body["text"]
    assert "Return only JSON." in body["input"][0]["content"][0]["text"]


def test_execute_structured_rejects_unknown_methods():
    tool = CodexStructuredTool(access_token="token", account_id="acct")

    with pytest.raises(ValueError, match="Unsupported structured execution method"):
        tool.execute_structured("prompt", SampleSchema, method="bogus")
