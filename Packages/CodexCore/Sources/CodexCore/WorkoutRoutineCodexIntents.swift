public enum WorkoutRoutineCodexIntents {
    public static func getWorkoutGenerationIntentInstructions(currentDateISO: String) -> String {
        NeuralLoopCodexIntents.getWorkoutGenerationIntentInstructions(currentDateISO: currentDateISO)
    }

    public static let workoutGenerationIntentTools: [CodexTool] = NeuralLoopCodexIntents.workoutGenerationIntentTools
}
