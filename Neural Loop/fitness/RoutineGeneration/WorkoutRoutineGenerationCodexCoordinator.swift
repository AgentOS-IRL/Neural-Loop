import Combine
import Foundation
import CodexCore

protocol WorkoutRoutineGenerationCodexExecuting {
    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult
}

@MainActor
protocol WorkoutRoutineGenerationCodexModel: AnyObject {
    var llm_enabled: Bool { get }
    var codexAccessToken: String? { get }
    var codexAccountID: String? { get }
    func validCodexCredentials() async -> CodexCredentials?
}

@MainActor
final class WorkoutRoutineGenerationCodexCoordinator: ObservableObject {
    @Published private(set) var isGenerating = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private let model: any WorkoutRoutineGenerationCodexModel
    private let dataManager: any WorkoutCatalogReading
    private let codexClient: (any WorkoutRoutineGenerationCodexExecuting)?

    init(
        model: any WorkoutRoutineGenerationCodexModel,
        dataManager: any WorkoutCatalogReading,
        codexClient: (any WorkoutRoutineGenerationCodexExecuting)? = nil
    ) {
        self.model = model
        self.dataManager = dataManager
        self.codexClient = codexClient
    }

    var canGenerate: Bool {
        model.llm_enabled && !isGenerating
    }

    func generateRoutine(prompt: String) async -> WorkoutRoutineGenerationPayload? {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            appendError("Enter a workout routine prompt before generating.")
            return nil
        }

        guard model.llm_enabled else {
            appendError("LLM access is disabled.")
            return nil
        }

        guard let client = await resolvedCodexClient() else {
            appendError("Codex client is unavailable.")
            return nil
        }

        isGenerating = true
        statusMessage = "Generating workout routine..."
        errorMessage = nil
        defer {
            isGenerating = false
            if statusMessage == "Generating workout routine..." {
                statusMessage = nil
            }
        }

        do {
            let catalog = try await loadCatalog()
            let catalogItems = catalog.map {
                WorkoutRoutineCodexIntents.CatalogItem(
                    exerciseName: $0.name,
                    equipmentName: $0.equipmentName
                )
            }
            let result = try await client.converse(
                messages: [
                    CodexInputMessage(
                        role: "user",
                        content: [CodexInputContent(type: "input_text", text: trimmedPrompt)]
                    )
                ],
                state: CodexConversationState(),
                tools: WorkoutRoutineCodexIntents.workoutGenerationIntentTools,
                instructions: WorkoutRoutineCodexIntents.getWorkoutGenerationIntentInstructions(
                    currentDateISO: ISO8601DateFormatter().string(from: Date()),
                    catalog: catalogItems
                )
            )

            switch result.action {
            case .callTool(let name, let arguments):
                guard normalizedToolName(name) == "generate_workout_routine" else {
                    appendError("Unexpected Codex tool call: \(name)")
                    return nil
                }

                let generatedRoutine = try decodeRoutine(arguments)
                let filteredRoutine = WorkoutCatalogMapper.filteredRoutine(
                    generatedRoutine,
                    matching: catalog
                )
                statusMessage = nil
                return filteredRoutine

            case .clarify(let text):
                appendError(text)
                return nil
            }
        } catch {
            appendError(error.localizedDescription)
            return nil
        }
    }

    private func loadCatalog() async throws -> [ExerciseLibraryItem] {
        async let equipmentRows = dataManager.fetchAllEquipment()
        async let exerciseRows = dataManager.fetchAllExercisesWithMuscles()
        let (equipment, exercises) = try await (equipmentRows, exerciseRows)
        return WorkoutCatalogMapper.makeLibraryItems(equipment: equipment, exercises: exercises)
    }

    private func decodeRoutine(_ arguments: [String: Any]) throws -> WorkoutRoutineGenerationPayload {
        guard JSONSerialization.isValidJSONObject(arguments) else {
            throw WorkoutRoutineGenerationCodexCoordinatorError.malformedPayload
        }

        let data = try JSONSerialization.data(withJSONObject: arguments, options: [])
        do {
            return try JSONDecoder().decode(WorkoutRoutineGenerationPayload.self, from: data)
        } catch {
            throw WorkoutRoutineGenerationCodexCoordinatorError.malformedPayload
        }
    }

    private func resolvedCodexClient() async -> (any WorkoutRoutineGenerationCodexExecuting)? {
        if let codexClient {
            return codexClient
        }

        guard let credentials = await model.validCodexCredentials() else {
            return nil
        }

        return CodexStructuredToolWorkoutRoutineAdapter(
            tool: CodexStructuredTool(access_token: credentials.accessToken, account_id: credentials.accountID)
        )
    }

    private func appendError(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        errorMessage = trimmed
        statusMessage = nil
    }

    private func normalizedToolName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private enum WorkoutRoutineGenerationCodexCoordinatorError: LocalizedError {
    case malformedPayload

    var errorDescription: String? {
        switch self {
        case .malformedPayload:
            return "Codex returned an invalid workout routine payload."
        }
    }
}

final class CodexStructuredToolWorkoutRoutineAdapter: WorkoutRoutineGenerationCodexExecuting {
    private let tool: CodexStructuredTool

    init(tool: CodexStructuredTool) {
        self.tool = tool
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        try await tool.converse(
            messages: messages,
            state: state,
            tools: tools,
            instructions: instructions
        )
    }
}

extension UnifiedDataModel: WorkoutRoutineGenerationCodexModel {}
