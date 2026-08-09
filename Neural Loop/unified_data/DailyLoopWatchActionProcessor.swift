import Foundation
import SwiftData

enum DailyLoopWatchMutationError: LocalizedError {
    case taskNotFound
    case habitNotFound
    case missingOccurrence
    case unexpectedOccurrence
    case emptyNote
    case unsupportedSchema

    var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task is no longer available."
        case .habitNotFound:
            return "Habit is no longer available."
        case .missingOccurrence:
            return "The recurring task occurrence is missing."
        case .unexpectedOccurrence:
            return "This task does not use recurring occurrences."
        case .emptyNote:
            return "The note is empty."
        case .unsupportedSchema:
            return "Update Neural Loop on both devices and try again."
        }
    }
}

private struct DailyLoopProcessedActionLedger {
    private struct StoredLedger: Codable {
        var results: [DailyLoopWatchActionResult]
    }

    private let storageKey = "com.neuralloop.iphone.dailyLoopProcessedActions.v1"
    private let maximumCount = 256
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func result(for actionID: UUID) -> DailyLoopWatchActionResult? {
        load().results.first { $0.actionID == actionID }
    }

    func store(_ result: DailyLoopWatchActionResult) {
        var ledger = load()
        ledger.results.removeAll { $0.actionID == result.actionID }
        ledger.results.append(result)
        ledger.results.sort { $0.processedAt < $1.processedAt }
        if ledger.results.count > maximumCount {
            ledger.results.removeFirst(ledger.results.count - maximumCount)
        }

        guard let data = try? encoder.encode(ledger) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func load() -> StoredLedger {
        guard
            let data = defaults.data(forKey: storageKey),
            let ledger = try? decoder.decode(StoredLedger.self, from: data)
        else {
            return StoredLedger(results: [])
        }
        return ledger
    }
}

/// Serializes all watch-authored Daily Loop mutations on the authoritative
/// iPhone. Successful results are persisted before replying so a lost reply
/// can be answered without repeating the mutation.
@MainActor
final class DailyLoopWatchActionProcessor {
    static let shared = DailyLoopWatchActionProcessor()

    private var model: UnifiedDataModel?
    private var modelContext: ModelContext?
    private weak var connectivity: ConnectivityManager?
    private let ledger = DailyLoopProcessedActionLedger()
    private var pendingActions: [DailyLoopWatchAction] = []
    private var processingActionID: UUID?

    private init() {}

    func configure(
        model: UnifiedDataModel,
        modelContext: ModelContext,
        connectivity: ConnectivityManager? = nil
    ) {
        let connectivity = connectivity ?? .shared
        self.model = model
        self.modelContext = modelContext
        self.connectivity = connectivity

        connectivity.dailyLoopActionHandler = { [weak self] action in
            self?.receive(action)
        }

        if let action = connectivity.lastDailyLoopAction {
            receive(action)
        }
    }

    private func receive(_ action: DailyLoopWatchAction) {
        if let storedResult = ledger.result(for: action.id) {
            connectivity?.sendDailyLoopActionResult(storedResult)
            return
        }

        guard processingActionID != action.id,
              !pendingActions.contains(where: { $0.id == action.id }) else {
            return
        }

        pendingActions.append(action)
        processNextIfNeeded()
    }

    private func processNextIfNeeded() {
        guard processingActionID == nil,
              let action = pendingActions.first,
              let model,
              let modelContext else {
            return
        }

        processingActionID = action.id
        Task { @MainActor [weak self] in
            await self?.process(action, model: model, modelContext: modelContext)
        }
    }

    private func process(
        _ action: DailyLoopWatchAction,
        model: UnifiedDataModel,
        modelContext: ModelContext
    ) async {
        let result: DailyLoopWatchActionResult

        do {
            guard action.schemaVersion == DailyLoopWatchAction.currentSchemaVersion else {
                throw DailyLoopWatchMutationError.unsupportedSchema
            }

            try await apply(action, model: model, modelContext: modelContext)
            let completions = try modelContext.fetch(FetchDescriptor<CompletedRecurringTask>())
            model.updateDailyLoopRecurringCompletions(completions)
            let snapshot = model.makeDailyLoopWatchSnapshot()
            ConnectivityManager.shared.sendDailyLoopSnapshot(snapshot)

            result = DailyLoopWatchActionResult(
                actionID: action.id,
                processedSequence: action.sequence,
                status: .succeeded,
                authoritativeSnapshot: snapshot
            )

            // Persist before replying. Only successful mutations are retained;
            // failed actions remain retryable with the same UUID and sequence.
            ledger.store(result)
        } catch {
            let snapshot = model.makeDailyLoopWatchSnapshot()
            result = DailyLoopWatchActionResult(
                actionID: action.id,
                processedSequence: action.sequence,
                status: .failed,
                message: error.localizedDescription,
                authoritativeSnapshot: snapshot
            )
        }

        connectivity?.sendDailyLoopActionResult(result)
        pendingActions.removeAll { $0.id == action.id }
        processingActionID = nil
        processNextIfNeeded()
    }

    private func apply(
        _ action: DailyLoopWatchAction,
        model: UnifiedDataModel,
        modelContext: ModelContext
    ) async throws {
        switch action.payload {
        case .setTaskCompletion(let payload):
            if let occurrenceStart = payload.identity.occurrenceStart {
                try await model.setRecurringTaskCompletedFromWatch(
                    taskId: payload.identity.taskID,
                    occurrenceStart: occurrenceStart,
                    completed: payload.isCompleted,
                    context: modelContext
                )
            } else {
                try await model.setTaskCompletedFromWatch(
                    taskId: payload.identity.taskID,
                    completed: payload.isCompleted
                )
            }

        case .setHabitProgressAtLeast(let payload):
            try await model.setHabitProgressAtLeastFromWatch(
                habitID: payload.habitID,
                minimumValue: max(0, payload.minimumValue)
            )

        case .setHabitSkipped(let payload):
            guard let habit = model.habits.first(where: { $0.id == payload.habitID }) else {
                throw DailyLoopWatchMutationError.habitNotFound
            }
            if payload.isSkipped {
                await model.skipHabitToday(habit)
            } else {
                await model.unskipHabitToday(habit)
            }

        case .createFleetingNote(let payload):
            let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw DailyLoopWatchMutationError.emptyNote
            }
            _ = try await model.manager.createFleetingNoteFromWatch(
                text: text,
                actionID: action.id
            )
        }
    }
}
