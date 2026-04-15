from __future__ import annotations

import json
import uuid
from typing import Any, Callable, Iterable, TypeVar
from urllib.request import Request, urlopen

from pydantic import BaseModel

DEFAULT_URL = "https://chatgpt.com/backend-api/codex/responses"
DEFAULT_MODEL = "gpt-5.1-codex"
DEFAULT_INSTRUCTIONS = "You are a helpful assistant."
DEFAULT_TIMEOUT = 60
DEFAULT_USER_AGENT = "python-codex-client/1.0"

Transport = Callable[[str, dict[str, str], bytes, float], Iterable[str]]
SchemaT = TypeVar("SchemaT", bound=BaseModel)


def _default_transport(url: str, headers: dict[str, str], body: bytes, timeout: float) -> Iterable[str]:
    request = Request(url, data=body, headers=headers, method="POST")
    with urlopen(request, timeout=timeout) as response:  # nosec - caller controls target URL
        for raw_line in response:
            yield raw_line.decode("utf-8", errors="replace")


class CodexStructuredTool:
    def __init__(
        self,
        access_token: str,
        account_id: str,
        model: str = DEFAULT_MODEL,
        url: str = DEFAULT_URL,
        instructions: str = DEFAULT_INSTRUCTIONS,
        timeout: float = DEFAULT_TIMEOUT,
        *,
        transport: Transport | None = None,
        session_id_factory: Callable[[], str] | None = None,
    ) -> None:
        self.access_token = access_token
        self.account_id = account_id
        self.model = model
        self.url = url
        self.instructions = instructions
        self.timeout = timeout
        self._transport = transport or _default_transport
        self._session_id_factory = session_id_factory or (lambda: str(uuid.uuid4()))

    def _build_headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.access_token}",
            "chatgpt-account-id": self.account_id,
            "OpenAI-Beta": "responses=experimental",
            "originator": "codex_cli_rs",
            "session_id": self._session_id_factory(),
            "accept": "text/event-stream",
            "content-type": "application/json",
            "User-Agent": DEFAULT_USER_AGENT,
        }

    def _build_body(
        self,
        prompt: str,
        instructions: str | None = None,
        text_format: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {
            "model": self.model,
            "stream": True,
            "store": False,
            "instructions": self.instructions if instructions is None else instructions,
            "text": {"verbosity": "medium"},
            "input": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_text",
                            "text": prompt,
                        }
                    ],
                }
            ],
        }
        if text_format is not None:
            body["text"]["format"] = text_format
        return body

    def _extract_text_from_event(self, event: dict[str, Any]) -> str:
        event_type = event.get("type")
        if event_type == "response.output_text.delta":
            delta = event.get("delta", "")
            return delta if isinstance(delta, str) else str(delta)

        if event_type in {"response.output_text.done", "response.completed"}:
            response = event.get("response") or {}
            output = response.get("output") or []
            parts: list[str] = []
            for output_item in output:
                content_items = output_item.get("content") or []
                for content_item in content_items:
                    text = content_item.get("text")
                    if isinstance(text, str):
                        parts.append(text)
            return "".join(parts)

        return ""

    def _post_and_collect_text(
        self,
        prompt: str,
        url: str | None = None,
        instructions: str | None = None,
        text_format: dict[str, Any] | None = None,
    ) -> str:
        request_url = url or self.url
        headers = self._build_headers()
        body = json.dumps(self._build_body(prompt, instructions=instructions, text_format=text_format)).encode("utf-8")

        parts: list[str] = []
        for line in self._transport(request_url, headers, body, self.timeout):
            if not line:
                continue

            normalized = line.strip()
            if not normalized.startswith("data:"):
                continue

            payload = normalized[5:].lstrip()
            if not payload:
                continue
            if payload == "[DONE]":
                break

            event = json.loads(payload)
            chunk = self._extract_text_from_event(event)
            if chunk:
                parts.append(chunk)

        return "".join(parts)

    def execute_sync(self, prompt: str, url: str | None = None) -> str:
        return self._post_and_collect_text(prompt, url=url)

    def execute_structured(
        self,
        prompt: str,
        Schema: type[SchemaT],
        method: str = "json_schema",
        strict: bool = False,
        include_raw: bool = False,
    ) -> SchemaT | dict[str, Any]:
        parser_instructions = self._parser_format_instructions(Schema)

        if method == "json_schema":
            schema_json = Schema.model_json_schema()
            if strict:
                schema_json["additionalProperties"] = False
            text_format: dict[str, Any] | None = {
                "type": "json_schema",
                "name": Schema.__name__,
                "strict": strict,
                "schema": schema_json,
            }
            final_prompt = prompt
        elif method in {"json_mode", "function_calling"}:
            final_prompt = f"{prompt}\nReturn only JSON.\n{parser_instructions}"
            text_format = {"type": "json_object"} if method == "json_mode" else None
        else:
            raise ValueError(f"Unsupported structured execution method: {method}")

        raw = self._post_and_collect_text(final_prompt, text_format=text_format)
        parsed = Schema.model_validate_json(raw)
        if include_raw:
            return {"raw": raw, "parsed": parsed}
        return parsed

    def _parser_format_instructions(self, schema: type[BaseModel]) -> str:
        field_names = ", ".join(schema.model_fields.keys())
        return (
            "Return a JSON object only. "
            "Do not wrap the result in markdown fences or any extra text. "
            f"The JSON should match the schema fields: {field_names}."
        )
