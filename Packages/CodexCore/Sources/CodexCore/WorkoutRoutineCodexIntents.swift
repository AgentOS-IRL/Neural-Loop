public enum WorkoutRoutineCodexIntents {
    public struct CatalogItem: Equatable, Sendable {
        public let exerciseName: String
        public let equipmentName: String

        public init(exerciseName: String, equipmentName: String) {
            self.exerciseName = exerciseName
            self.equipmentName = equipmentName
        }
    }

    public static func getWorkoutGenerationIntentInstructions(
        currentDateISO: String,
        catalog: [CatalogItem]
    ) -> String {
        let catalogText = formatCatalog(catalog)

        return """
        You are an assistant that generates workout routines.
        CURRENT DATE AND TIME: \(currentDateISO).
        Use the exercise catalog below to choose exact exercise names and equipment pairings whenever possible.
        If multiple entries are similar, prefer the closest exact catalog match instead of inventing a new exercise.
        If the catalog says "No equipment", send an empty equipment string in the tool payload.

        Exercise catalog:
        \(catalogText)

        you must call generate_workout_routine tool based on the user message.
        Do not invent exercises, equipment, or routine structure on your own.
        You only task is to call generate_workout_routine tool based on the user message.
        """
    }

    public static func getWorkoutGenerationIntentInstructions(currentDateISO: String) -> String {
        getWorkoutGenerationIntentInstructions(currentDateISO: currentDateISO, catalog: [])
    }

    public static let workoutGenerationIntentTools: [CodexTool] = [
        CodexTool(
            name: "generate_workout_routine",
            description: "Generate a workout routine payload. Only use this tool when the user is asking for a routine or workout template. Do not invent exercises. Return routine_name, notes, and an exercises array with name and equipment for each proposed exercise. The app will validate the proposed exercises against its catalog and remove invalid entries before showing the result.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "routine_name": .object([
                        "type": .string("string"),
                        "description": .string("Short routine title.")
                    ]),
                    "notes": .object([
                        "type": .string("string"),
                        "description": .string("Optional routine notes and coaching context.")
                    ]),
                    "exercises": .object([
                        "type": .string("array"),
                        "description": .string("Ordered workout exercises proposed for the routine. Keep the order stable."),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "name": .object([
                                    "type": .string("string"),
                                    "description": .string("Exercise name.")
                                ]),
                                "equipment": .object([
                                    "type": .string("string"),
                                    "description": .string("Equipment name, or an empty string if the exercise uses no equipment.")
                                ])
                            ]),
                            "required": .array([
                                .string("name"),
                                .string("equipment")
                            ])
                        ])
                    ])
                ]),
                "required": .array([
                    .string("routine_name"),
                    .string("notes"),
                    .string("exercises")
                ])
            ])
        )
    ]

    private static func formatCatalog(_ catalog: [CatalogItem]) -> String {
        guard !catalog.isEmpty else {
            return "- (no workout catalog entries available)"
        }

        return catalog
            .sorted {
                let exerciseComparison = $0.exerciseName.localizedCaseInsensitiveCompare($1.exerciseName)
                if exerciseComparison == .orderedSame {
                    return $0.equipmentName.localizedCaseInsensitiveCompare($1.equipmentName) == .orderedAscending
                }
                return exerciseComparison == .orderedAscending
            }
            .map { item in
                "- \(item.exerciseName) | equipment: \(item.equipmentName)"
            }
            .joined(separator: "\n")
    }
}
