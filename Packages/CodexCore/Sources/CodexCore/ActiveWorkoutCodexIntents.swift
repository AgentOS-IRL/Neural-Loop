import Foundation

public enum ActiveWorkoutCodexIntents {
    public static func getActiveWorkoutUpdateIntentInstructions(currentDateISO: String) -> String {
        """
        You are an assistant that updates the active workout session from a text command.
        CURRENT DATE AND TIME: \(currentDateISO).
        The active session is ordered by exercise order, then set order. When updating, target the first set that is not done.
        Do not ask the user to name the exercise or set. Use the active session's ordering to decide which set to update.

        If the user message does not contain enough information to safely update the set, do not call a tool. Respond with a clarification question instead.
        Do not invent numbers, units, or metrics.

        Rep-based updates should use weight and reps.
        Cardio updates should use distance_meters, duration_minutes, and calories when those values are provided.

        Your only task is to call update_set when the message provides enough information, otherwise ask for clarification.
        """
    }

    public static func getActiveWorkoutUpdateIntentInstructions() -> String {
        getActiveWorkoutUpdateIntentInstructions(currentDateISO: ISO8601DateFormatter().string(from: Date()))
    }

    public static let activeWorkoutUpdateIntentTools: [CodexTool] = [
        CodexTool(
            name: "update_set",
            description: "Update the first incomplete set in the active workout session. Use this tool only when the user provided enough information to safely update the active session. Provide only the metrics explicitly mentioned by the user. If the user did not provide enough detail, do not call this tool; ask for clarification instead.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "weight": .object([
                        "type": .string("number"),
                        "description": .string("Optional lifted weight value.")
                    ]),
                    "reps": .object([
                        "type": .string("number"),
                        "description": .string("Optional reps value.")
                    ]),
                    "distance_meters": .object([
                        "type": .string("number"),
                        "description": .string("Optional cardio distance in meters.")
                    ]),
                    "duration_minutes": .object([
                        "type": .string("number"),
                        "description": .string("Optional cardio duration in minutes.")
                    ]),
                    "calories": .object([
                        "type": .string("number"),
                        "description": .string("Optional cardio calories value.")
                    ])
                ])
            ])
        )
    ]
}
