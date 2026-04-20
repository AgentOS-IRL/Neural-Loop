# CodexCore

```bash
cd /Users/sanjeevhalyal/projects/Neural-Loop/Packages/CodexCore
swift test
```

## Chat Conversation Script

The package includes a local conversation runner for manually exercising the
Codex chat flow with the same `create_task` and `Notes` tool contract used by
audio mode. Grocery and shopping-list prompts are split into one parent task
plus item subtasks. Tool calls are handled by dummy executors that print the
task or note payload instead of saving into the app.

Set up local credentials:

```bash
cp .env.example .env
```

Fill in `CODEX_ACCESS_TOKEN` and `CODEX_ACCOUNT_ID` in `.env`. The `.env` file
is ignored by git.

Run an interactive conversation:

```bash
bash Scripts/chat_conversation.sh
```

Run a single prompt:

```bash
bash Scripts/chat_conversation.sh "create a task to call the dentist tomorrow afternoon"
```

```bash
bash Scripts/chat_conversation.sh "make me a grocery list with milk, eggs, and bread"
```
