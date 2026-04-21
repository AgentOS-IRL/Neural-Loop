public enum NeuralLoopCodexIntents {
    public static func getDefaultIntentInstructions(currentDateISO: String) -> String {
        return """
        You are an assistant with two tools: create_task for top-level to-dos and Notes for fleeting notes saved in the app.
        CURRENT DATE AND TIME: \(currentDateISO).
        If the user's intent is clear, call the appropriate tool. If the input is vague or missing details, do not call a tool; respond with a clarification question.

        Task Rules:
        - Watch for dates, times, and dayparts. Calculate the `start_date` as a normalized ISO-8601 string based on the CURRENT DATE AND TIME.
        - If the user specifies a date but no exact time, default the time to 15:00:00 (3:00 PM) local time and mention this assumption in the `description`.
        - If the user specifies a duration (e.g., "for half an hour"), calculate the `duration` in seconds (e.g., 1800).

        Grocery and shopping-list rules:
        - Treat phrases like "grocery todo", "grocery list", and "shopping list" as a special todo type.
        - Handle known grocery items with one `create_task` call that includes a `sub_tasks` array.
        - Create one parent task for the grocery list itself with create_task.
        - If the user names grocery items in the same request, include them in the same create_task call as a sub_tasks array so the app can save the parent first and then create each subtodo automatically.
        - If the user asks for a grocery list but does not name any items, ask for clarification instead of inventing items.
        - Grocery requests should be handled in one create_task call whenever the list items are known in the same turn.

        Subtask payload rules:
        - When using sub_tasks on create_task, trim each child title and do not include empty or whitespace-only entries.
        """
    }
    public static let defaultIntentTools: [CodexTool] = [
        CodexTool(
            name: "create_task",
            description: "Create a to-do item when the user wants to add a task. Include start_date when the user mentions a date, time, morning, afternoon, or evening. Use an ISO-8601 string when possible. If only a date is known, assume afternoon and mention that assumption in description. If the user includes subtodos in the same request, add them to sub_tasks so the app can save the parent first and then create each subtodo automatically in one call. If start_date is present and duration is omitted, the app defaults duration to 900 seconds.",
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
                    ]),
                    "sub_tasks": .object([
                        "type": .string("array"),
                        "description": .string("Optional subtodos to create after the parent task is saved. Each entry must include a trimmed title."),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "title": .object([
                                    "type": .string("string"),
                                    "description": .string("Trimmed subtask title.")
                                ])
                            ]),
                            "required": .array([
                                .string("title")
                            ])
                        ])
                    ])
                ]),
                "required": .array([
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
