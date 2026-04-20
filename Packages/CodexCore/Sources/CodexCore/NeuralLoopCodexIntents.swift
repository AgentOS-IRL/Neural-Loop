public enum NeuralLoopCodexIntents {
    public static func getDefaultIntentInstructions(currentDateISO: String) -> String {
        return """
        You are an assistant with three tools: create_task for top-level to-dos, create_sub_task for subtasks that belong to an existing task, and Notes for fleeting notes saved in the app.
        CURRENT DATE AND TIME: \(currentDateISO).
        If the user's intent is clear, call the appropriate tool. If the input is vague or missing details, do not call a tool; respond with a clarification question.

        Task Rules:
        - Watch for dates, times, and dayparts. Calculate the `start_date` as a normalized ISO-8601 string based on the CURRENT DATE AND TIME.
        - If the user specifies a date but no exact time, default the time to 15:00:00 (3:00 PM) local time and mention this assumption in the `description`.
        - If the user specifies a duration (e.g., "for half an hour"), calculate the `duration` in seconds (e.g., 1800).

        Grocery and shopping-list rules:
        - Treat phrases like "grocery todo", "grocery list", and "shopping list" as a special todo type that should be decomposed into item subtasks.
        - Create one parent task for the grocery list itself with create_task.
        - Create one create_sub_task call for each distinct grocery item the user names, using the parent task's task_id.
        - Trim each grocery item title before sending it to create_sub_task, and do not create empty or whitespace-only subtasks.
        - If the user asks for a grocery list but does not name any items, ask for clarification instead of inventing items.
        - It is valid to call create_sub_task multiple times for the same grocery parent task.

        Subtask Rules:
        - Use create_sub_task only when the parent task is already known from the conversation or explicitly provided by the user.
        - Require a `task_id` for the parent task and a trimmed `title` for the subtask.
        - If the parent task is missing or ambiguous, ask which task the subtask belongs to instead of guessing.
        """
    }
    public static let defaultIntentTools: [CodexTool] = [
        CodexTool(
            name: "create_task",
            description: "Create a to-do item when the user wants to add a task. Include start_date when the user mentions a date, time, morning, afternoon, or evening. Use an ISO-8601 string when possible. If only a date is known, assume afternoon and mention that assumption in description. If start_date is present and duration is omitted, the app defaults duration to 900 seconds.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Short task title.")
                    ]),
                    "description": .object([
                        "type": .string("string"),
                        "description": .string("Optional task details. Mention scheduling assumptions here when you infer a default time such as afternoon.")
                    ]),
                    "start_date": .object([
                        "type": .string("string"),
                        "description": .string("Optional normalized ISO-8601 start date. If the user gives only a date and no time, use that date with an afternoon time.")
                    ]),
                    "duration": .object([
                        "type": .string("number"),
                        "description": .string("Optional task duration in seconds. If omitted for scheduled tasks, the app defaults duration to 900 seconds.")
                    ])
                ]),
                "required": .array([
                    .string("title")
                ])
            ])
        ),
        CodexTool(
            name: "create_sub_task",
            description: "Create a subtask for an existing to-do. Only use this when the parent task is already known. Require task_id and title, trim whitespace before saving, and ask for clarification if the parent task is missing or ambiguous. It is valid to call this repeatedly for the same parent task, including to add grocery-item subtasks under a grocery list.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "task_id": .object([
                        "type": .string("number"),
                        "description": .string("Identifier for the existing parent task.")
                    ]),
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Short subtask title.")
                    ])
                ]),
                "required": .array([
                    .string("task_id"),
                    .string("title")
                ])
            ])
        ),
        CodexTool(
            name: "Notes",
            description: "Create a fleeting note in the app when the user wants to save general information or a note.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "content": .object([
                        "type": .string("string")
                    ]),
                    "note": .object([
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
