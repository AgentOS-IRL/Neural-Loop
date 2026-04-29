import Foundation
import CodexCore

@MainActor
protocol WorkoutSiriUpdating: AnyObject {
    func updateWorkout(note: String) async -> WorkoutSiriUpdateOutcome
}

@MainActor
protocol WorkoutSiriCodexModel: AnyObject {
    var llm_enabled: Bool { get }
    var codexAccessToken: String? { get }
    var codexAccountID: String? { get }
}

enum WorkoutSiriUpdateOutcome: Equatable {
    case updated(String)
    case clarify(String)
    case noActiveSession(String)
    case unavailable(String)

    var spokenText: String {
        switch self {
        case .updated(let text), .clarify(let text), .noActiveSession(let text), .unavailable(let text):
            return text
        }
    }
}

@MainActor
final class WorkoutSiriUpdateService: WorkoutSiriUpdating {
    private let model: any WorkoutSiriCodexModel
    private let persistenceManager: WorkoutDraftPersistenceManager
    private let connectivityProvider: WorkoutConnectivityProviding
    private let liveActivityUpdater: any WorkoutSiriLiveActivityUpdating
    private let codexClient: (any WorkoutSiriCodexExecuting)?

    init(
        model: any WorkoutSiriCodexModel = UnifiedDataModel.shared,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager(),
        connectivityProvider: WorkoutConnectivityProviding = ConnectivityManager.shared,
        liveActivityUpdater: any WorkoutSiriLiveActivityUpdating = WorkoutLiveActivityManagerAdapter(),
        codexClient: (any WorkoutSiriCodexExecuting)? = nil
    ) {
        self.model = model
        self.persistenceManager = persistenceManager
        self.connectivityProvider = connectivityProvider
        self.liveActivityUpdater = liveActivityUpdater
        self.codexClient = codexClient
    }

    func updateWorkout(note: String) async -> WorkoutSiriUpdateOutcome {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            return .clarify("What should I update in your workout?")
        }

        guard model.llm_enabled else {
            return .unavailable("Workout updates need LLM access to be enabled in the app.")
        }

        guard let accessToken = model.codexAccessToken, let accountID = model.codexAccountID else {
            return .unavailable("Workout updates need your Codex credentials to be loaded in the app.")
        }

        guard let pointer = persistenceManager.loadActiveSessionPointer(),
              let routineID = pointer.routineID,
              var draft = persistenceManager.load(routineID: routineID) else {
            return .noActiveSession("I can't find an active workout session. Start one first.")
        }

        guard let client = resolvedCodexClient(accessToken: accessToken, accountID: accountID) else {
            return .unavailable("Workout updates need Codex access before I can update the set.")
        }

        do {
            let result = try await client.converse(
                messages: [
                    CodexInputMessage(
                        role: "user",
                        content: [CodexInputContent(type: "input_text", text: trimmedNote)]
                    )
                ],
                state: CodexConversationState(),
                tools: ActiveWorkoutCodexIntents.activeWorkoutUpdateIntentTools,
                instructions: ActiveWorkoutCodexIntents.getActiveWorkoutUpdateIntentInstructions(
                    currentDateISO: ISO8601DateFormatter().string(from: Date())
                ),
                toolChoice: .object([
                    "type": .string("function"),
                    "name": .string("update_set")
                ])
            )

            switch result.action {
            case .callTool(let name, let arguments):
                guard normalizedToolName(name) == "update_set" else {
                    return .clarify("I couldn't interpret that workout update.")
                }

                guard let update = extractUpdate(from: arguments) else {
                    return .clarify("What weight, reps, distance, duration, or calories should I use?")
                }
                guard update.hasAnyValue else {
                    return .clarify("What weight, reps, distance, duration, or calories should I use?")
                }

                guard let target = firstIncompleteSet(in: draft) else {
                    return .noActiveSession("Your active workout is already complete.")
                }

                apply(update: update, to: &draft, at: target)
                draft.updatedAt = Date()
                draft.revision += 1
                persistenceManager.save(draft: draft)
                persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)

                let snapshot = draft.watchSnapshot()
                connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                liveActivityUpdater.update(snapshot: snapshot)

                return .updated(buildConfirmationText(for: update, setNumber: draft.exercises[target.exerciseIndex].sets[target.setIndex].setNumber))

            case .clarify(let text):
                return .clarify(text)
            }
        } catch {
            return .unavailable("I couldn't update your workout right now. \(error.localizedDescription)")
        }
    }

    private func resolvedCodexClient(
        accessToken: String,
        accountID: String
    ) -> (any WorkoutSiriCodexExecuting)? {
        if let codexClient {
            return codexClient
        }

        return CodexStructuredToolWorkoutSiriAdapter(
            tool: CodexStructuredTool(access_token: accessToken, account_id: accountID)
        )
    }

    private func firstIncompleteSet(in draft: ActiveWorkoutDraft) -> (exerciseIndex: Int, setIndex: Int)? {
        for (exerciseIndex, exercise) in draft.exercises.enumerated() {
            if let setIndex = exercise.sets.firstIndex(where: { !$0.isCompleted }) {
                return (exerciseIndex, setIndex)
            }
        }
        return nil
    }

    private func apply(
        update: WorkoutSiriSetUpdate,
        to draft: inout ActiveWorkoutDraft,
        at target: (exerciseIndex: Int, setIndex: Int)
    ) {
        var applied = false
        if let weight = update.weight {
            applied = true
            draft.exercises[target.exerciseIndex].sets[target.setIndex].weightText = NumericFormatter.format(weight)
        }
        if let reps = update.reps {
            applied = true
            draft.exercises[target.exerciseIndex].sets[target.setIndex].repsText = "\(reps)"
        }
        if let distanceMeters = update.distanceMeters {
            let kilometers = distanceMeters / 1000
            applied = true
            draft.exercises[target.exerciseIndex].sets[target.setIndex].distanceText = NumericFormatter.format(kilometers)
        }
        if let durationMinutes = update.durationMinutes {
            applied = true
            draft.exercises[target.exerciseIndex].sets[target.setIndex].durationText = NumericFormatter.format(durationMinutes)
        }
        if let calories = update.calories {
            applied = true
            draft.exercises[target.exerciseIndex].sets[target.setIndex].caloriesText = NumericFormatter.format(calories)
        }
        if applied {
            draft.exercises[target.exerciseIndex].sets[target.setIndex].isCompleted = true
        }
    }

    private func extractUpdate(from arguments: [String: Any]) -> WorkoutSiriSetUpdate? {
        WorkoutSiriSetUpdate(
            weight: decimalValue(for: ["weight"], in: arguments),
            reps: intValue(for: ["reps"], in: arguments),
            distanceMeters: decimalValue(for: ["distance_meters", "distanceMeters"], in: arguments),
            durationMinutes: decimalValue(for: ["duration_minutes", "durationMinutes"], in: arguments),
            calories: decimalValue(for: ["calories"], in: arguments)
        )
    }

    private func buildConfirmationText(for update: WorkoutSiriSetUpdate, setNumber: Int) -> String {
        var parts: [String] = []

        if let weight = update.weight {
            parts.append("\(NumericFormatter.format(weight)) kg")
        }
        if let reps = update.reps {
            parts.append("\(reps) reps")
        }
        if let distanceMeters = update.distanceMeters {
            let kilometers = distanceMeters / 1000
            if kilometers > 1{
                parts.append("\(NumericFormatter.format(kilometers)) km")}
            
        }
        if let durationMinutes = update.durationMinutes {
            if durationMinutes > 0 {
            parts.append("\(NumericFormatter.format(durationMinutes)) minutes")}
        }
        if let calories = update.calories {
            if calories > 0 {
            parts.append("\(NumericFormatter.format(calories)) calories")}
        }

        guard !parts.isEmpty else {
            return "Updated set \(setNumber)."
        }

        let detailText = parts.joined(separator: ", ")
        return "Updated set \(setNumber) with \(detailText)."
    }

    private func decimalValue(for keys: [String], in arguments: [String: Any]) -> Decimal? {
        for key in keys {
            guard let rawValue = arguments[key] else { continue }

            if let decimal = rawValue as? Decimal {
                return decimal
            }
            if let number = rawValue as? NSNumber {
                return number.decimalValue
            }
            if let string = rawValue as? String, let decimal = NumericFormatter.parse(string) {
                return decimal
            }
        }
        return nil
    }

    private func intValue(for keys: [String], in arguments: [String: Any]) -> Int? {
        for key in keys {
            guard let rawValue = arguments[key] else { continue }

            if let int = rawValue as? Int {
                return int
            }
            if let number = rawValue as? NSNumber {
                return number.intValue
            }
            if let string = rawValue as? String, let int = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return int
            }
        }
        return nil
    }

    private func normalizedToolName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct WorkoutSiriSetUpdate: Equatable {
    let weight: Decimal?
    let reps: Int?
    let distanceMeters: Decimal?
    let durationMinutes: Decimal?
    let calories: Decimal?

    var hasAnyValue: Bool {
        weight != nil || reps != nil || distanceMeters != nil || durationMinutes != nil || calories != nil
    }
}

protocol WorkoutSiriLiveActivityUpdating {
    func update(snapshot: ActiveWorkoutSnapshot)
}

struct WorkoutLiveActivityManagerAdapter: WorkoutSiriLiveActivityUpdating {
    func update(snapshot: ActiveWorkoutSnapshot) {
        WorkoutLiveActivityManager.shared.updateActivity(snapshot: snapshot)
    }
}

protocol WorkoutSiriCodexExecuting {
    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String,
        toolChoice: JSONValue
    ) async throws -> CodexIntentResult
}

final class CodexStructuredToolWorkoutSiriAdapter: WorkoutSiriCodexExecuting {
    private let tool: CodexStructuredTool

    init(tool: CodexStructuredTool) {
        self.tool = tool
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String,
        toolChoice: JSONValue
    ) async throws -> CodexIntentResult {
        try await tool.converse(
            messages: messages,
            state: state,
            tools: tools,
            instructions: instructions,
            toolChoice: toolChoice
        )
    }
}

extension UnifiedDataModel: WorkoutSiriCodexModel {}
