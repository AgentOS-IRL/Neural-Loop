import Combine
import Foundation

@MainActor
final class WorkoutTemplateEditViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let summary: WorkoutTemplateSummary

    private let dataManager: any FitnessTemplateDataManaging
    private var hasLoaded = false

    init(
        summary: WorkoutTemplateSummary,
        dataManager: any FitnessTemplateDataManaging
    ) {
        self.summary = summary
        self.dataManager = dataManager
    }

    var canSave: Bool {
        !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else {
            return
        }

        await load()
    }

    func save() async -> Bool {
        guard canSave else {
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let updatedRoutine = try await dataManager.updateRoutine(
                Routine(
                    id: summary.id,
                    name: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
            )

            title = updatedRoutine.name
            notes = updatedRoutine.notes ?? ""
            hasLoaded = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let routine = try await dataManager.fetchRoutine(by: summary.id) else {
                throw WorkoutTemplateEditError.missingRoutine
            }

            title = routine.name
            notes = routine.notes ?? ""
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum WorkoutTemplateEditError: LocalizedError {
    case missingRoutine

    var errorDescription: String? {
        switch self {
        case .missingRoutine:
            return "Workout template could not be found."
        }
    }
}
