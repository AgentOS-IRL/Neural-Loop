public enum NeuralLoopCodexIntents {
    public static func getDefaultIntentInstructions(currentDateISO: String) -> String {
        return """
        You are an assistant with tools for creating app tasks, shopping lists, and notes.
        CURRENT DATE AND TIME: \(currentDateISO).
        If the user's intent is clear, call the appropriate tool. If the input is vague or missing details, do not call a tool; respond with a clarification question.

        Task Rules:
        - Use create_shopping_list for grocery or shopping-list requests.
        - Use create_task for other top-level to-dos and checklists.
        - Watch for dates, times, and dayparts. Calculate the `start_date` as a normalized ISO-8601 string based on the CURRENT DATE AND TIME.
        - If the user specifies a date but no exact time, default the time to 15:00:00 (3:00 PM) local time and mention this assumption in the `description`.
        - If the user specifies a duration (e.g., "for half an hour"), calculate the `duration` in seconds (e.g., 1800).
        - If the user wants to mark a task as a deadline (e.g., "make it a deadline", "set that as a deadline"), use the make_task_deadline tool. Pass the task_id of the task they are referring to, which can usually be inferred from recent tool results in the conversation.

        Note source rules:
        - The Notes tool accepts a `source` argument with values `personal` or `work`.
        - Personal notes are private/general notes saved in the app through Supabase.
        - Work notes are Genesys reminders.
        - If the user says work, Genesys, meeting follow-up, customer, colleague, or other explicit work context, use `source: "work"`.
        - If the user says personal, private, home, general note, or does not give a clear work context, use `source: "personal"`.
        - If source is ambiguous, default to `personal` unless the work context is explicit.
        """
    }

    public static let defaultIntentTools: [CodexTool] = [
        CodexTool(
            name: "create_task",
            description: "Create a top-level to-do item. Do not use this for grocery or shopping-list requests; use create_shopping_list instead. Include start_date when the user mentions a date, time, morning, afternoon, or evening. Use an ISO-8601 string when possible. If only a date is known, assume 15:00 local time and mention that assumption in description. If the user includes subtodos for a non-shopping checklist in the same request, add them to sub_tasks so the app can save the parent first and then create each subtodo automatically in one call. If start_date is present and duration is omitted, the app defaults duration to 900 seconds.",
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
            name: "create_shopping_list",
            description: "Create a grocery or shopping-list task. Use this for grocery todo, shopping list, supermarket, store, or errand-list requests. Require a location/store/place and the items the user named; ask for clarification if either is missing. Include start_date only when the user mentions a date, time, or daypart; if the user gives a date without a time, use 15:00 local time. If start_date is omitted, the app defaults to today at 15:00 local time.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "location": .object([
                        "type": .string("string"),
                        "description": .string("Required store, place, or shopping location.")
                    ]),
                    "items": .object([
                        "type": .string("array"),
                        "description": .string("Shopping items explicitly named by the user. Trim whitespace and do not invent items."),
                        "items": .object([
                            "type": .string("string"),
                            "description": .string("A single shopping item.")
                        ])
                    ]),
                    "start_date": .object([
                        "type": .string("string"),
                        "description": .string("Optional normalized ISO-8601 start date. If omitted, the app defaults to today at 15:00 local time.")
                    ])
                ]),
                "required": .array([
                    .string("location"),
                    .string("items")
                ])
            ])
        ),
        CodexTool(
            name: "Notes",
            description: "Create a personal app note or a Genesys work note when the user wants to save information.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "content": .object([
                        "type": .string("string"),
                        "description": .string("The note text to save.")
                    ]),
                    "note": .object([
                        "type": .string("string"),
                        "description": .string("Fallback note text for compatibility.")
                    ]),
                    "source": .object([
                        "type": .string("string"),
                        "description": .string("Where to save the note. Use personal for app/Supabase notes and work for Genesys reminders."),
                        "enum": .array([
                            .string("personal"),
                            .string("work")
                        ])
                    ])
                ]),
                "required": .array([
                    .string("content")
                ])
            ])
        ),
        CodexTool(
            name: "make_task_deadline",
            description: "Mark an existing task as a deadline. Use this when the user asks to make a task a deadline. You must provide the task_id of the task.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "task_id": .object([
                        "type": .string("number"),
                        "description": .string("The numeric ID of the task to mark as a deadline.")
                    ])
                ]),
                "required": .array([
                    .string("task_id")
                ])
            ])
        )
    ]

    
}
