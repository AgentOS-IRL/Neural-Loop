# Neural LoopTests

`Neural LoopTests/` contains the XCTest target for the `Neural Loop` scheme. The tests focus on app logic and UI-state helpers that can be verified without manual QA.

## Coverage Areas

- Audio transcription and speech detection state.
- Audio mode Codex coordination.
- Fleeting notes state and database behavior.
- Secrets loading and LLM enablement logic.
- `ContentView` and `TaskHub` navigation behavior.
- Theme and due-date formatting helpers.

## Running Tests

```bash
xcodebuild -project "Neural Loop.xcodeproj" -scheme "Neural Loop" test
```

Manual verification is not required.
