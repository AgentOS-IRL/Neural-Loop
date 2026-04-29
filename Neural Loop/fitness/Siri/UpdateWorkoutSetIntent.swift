import AppIntents
import Foundation

struct UpdateWorkoutSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Workout Set"
    static let description = IntentDescription("Updates the active workout session from a spoken note.")
    static var openAppWhenRun = false

    @Parameter(title: "Workout Note", requestValueDialog: "What did you do for your workout?")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Update workout with \(\.$note)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = await MainActor.run { WorkoutSiriUpdateService() }
        let outcome = await service.updateWorkout(note: note)
        return .result(dialog: "\(outcome.spokenText)")
    }
}

struct WorkoutAppShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UpdateWorkoutSetIntent(),
            phrases: [
                "Take a workout note in \(.applicationName)",
                "Log my workout with \(.applicationName)",
                "Record a workout using \(.applicationName)",
                "Update my workout in \(.applicationName)"
            ],
            shortTitle: "Update Workout",
            systemImageName: "dumbbell.fill"
        )
    }
}
