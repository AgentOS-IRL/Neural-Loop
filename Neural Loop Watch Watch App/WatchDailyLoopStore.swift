import Combine
import Foundation
import WidgetKit

enum WatchCaptureDeliveryState: String, Codable {
    case queued
    case saved
    case failed
}

struct WatchCaptureStatus: Codable, Equatable {
    let actionID: UUID
    let text: String
    var state: WatchCaptureDeliveryState
    var message: String?
}

struct WatchDailyLoopPersistence {
    private let snapshotKey = "com.neuralloop.watch.dailyLoopSnapshot"
    private let widgetSnapshotKey = "com.neuralloop.watch.dailyLoopWidgetSnapshot.v1"
    private let widgetKind = "DailyLoopComplicationWidget"
    private let actionsKey = "com.neuralloop.watch.dailyLoopActions.v1"
    private let sequenceKey = "com.neuralloop.watch.dailyLoopNextSequence.v1"
    private let captureStatusKey = "com.neuralloop.watch.dailyLoopCaptureStatus.v1"
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadSnapshot() -> DailyLoopWatchSnapshot? {
        guard
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? decoder.decode(DailyLoopWatchSnapshot.self, from: data),
            snapshot.schemaVersion == DailyLoopWatchSnapshot.currentSchemaVersion
        else {
            return nil
        }
        return snapshot
    }

    func saveSnapshot(_ snapshot: DailyLoopWatchSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite)?
            .set(data, forKey: widgetSnapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    func loadActions() -> [DailyLoopWatchAction] {
        guard
            let data = defaults.data(forKey: actionsKey),
            let actions = try? decoder.decode([DailyLoopWatchAction].self, from: data)
        else {
            return []
        }

        return actions
            .filter { $0.schemaVersion == DailyLoopWatchAction.currentSchemaVersion }
            .sorted { $0.sequence < $1.sequence }
    }

    func saveActions(_ actions: [DailyLoopWatchAction]) {
        guard let data = try? encoder.encode(actions) else { return }
        defaults.set(data, forKey: actionsKey)
    }

    func loadNextSequence(fallback: Int) -> Int {
        guard defaults.object(forKey: sequenceKey) != nil else { return fallback }
        return max(defaults.integer(forKey: sequenceKey), fallback)
    }

    func saveNextSequence(_ sequence: Int) {
        defaults.set(sequence, forKey: sequenceKey)
    }

    func loadCaptureStatus() -> WatchCaptureStatus? {
        guard let data = defaults.data(forKey: captureStatusKey) else { return nil }
        return try? decoder.decode(WatchCaptureStatus.self, from: data)
    }

    func saveCaptureStatus(_ status: WatchCaptureStatus?) {
        guard let status else {
            defaults.removeObject(forKey: captureStatusKey)
            return
        }
        guard let data = try? encoder.encode(status) else { return }
        defaults.set(data, forKey: captureStatusKey)
    }
}

@MainActor
final class WatchDailyLoopStore: ObservableObject {
    @Published private(set) var snapshot: DailyLoopWatchSnapshot?
    @Published private(set) var pendingActions: [DailyLoopWatchAction]
    @Published private(set) var captureStatus: WatchCaptureStatus?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isReachable: Bool

    private let connectivity: ConnectivityManager
    private let persistence: WatchDailyLoopPersistence
    private var nextSequence: Int
    private var inFlightActionID: UUID?
    private var acknowledgementTimeoutTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        connectivity: ConnectivityManager? = nil,
        persistence: WatchDailyLoopPersistence? = nil
    ) {
        let connectivity = connectivity ?? .shared
        let persistence = persistence ?? WatchDailyLoopPersistence()
        let actions = persistence.loadActions()

        self.connectivity = connectivity
        self.persistence = persistence
        self.snapshot = persistence.loadSnapshot()
        self.pendingActions = actions
        self.captureStatus = persistence.loadCaptureStatus()
        self.isReachable = connectivity.isReachable
        self.nextSequence = persistence.loadNextSequence(
            fallback: (actions.map(\.sequence).max() ?? 0) + 1
        )

        // The extension receives only the presentation snapshot. Queue and
        // capture delivery state remain in the watch app's private defaults.
        if let snapshot {
            persistence.saveSnapshot(snapshot)
        }

        // Rebuild optimistic state from the durable queue. This also covers a
        // termination after the queue was saved but before its UI snapshot.
        for action in actions {
            applyOptimistically(action)
        }

        connectivity.$lastDailyLoopSnapshot
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .filter { $0.schemaVersion == DailyLoopWatchSnapshot.currentSchemaVersion }
            .sink { [weak self] snapshot in
                self?.reconcile(with: snapshot)
            }
            .store(in: &cancellables)

        connectivity.$lastDailyLoopActionResult
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)

        connectivity.$isReachable
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] reachable in
                self?.isReachable = reachable
                if reachable {
                    self?.sendHeadIfPossible()
                } else {
                    self?.inFlightActionID = nil
                    self?.acknowledgementTimeoutTask?.cancel()
                }
            }
            .store(in: &cancellables)

        // Subscribe before checking context so a disconnected launch receives
        // the most recently delivered snapshot without a race.
        connectivity.checkApplicationContext()
        sendHeadIfPossible()
    }

    var pendingCount: Int { pendingActions.count }

    func setTask(_ task: DailyLoopWatchTaskSummary, completed: Bool) {
        enqueue(
            .setTaskCompletion(DailyLoopTaskCompletionAction(
                identity: task.identity,
                isCompleted: completed
            ))
        )
    }

    func incrementHabit(_ habit: DailyLoopWatchHabitSummary) {
        enqueue(
            .setHabitProgressAtLeast(DailyLoopHabitProgressAction(
                habitID: habit.id,
                minimumValue: habit.current + 1
            ))
        )
    }

    func setHabit(_ habit: DailyLoopWatchHabitSummary, skipped: Bool) {
        enqueue(
            .setHabitSkipped(DailyLoopHabitSkipAction(
                habitID: habit.id,
                isSkipped: skipped
            ))
        )
    }

    @discardableResult
    func captureNote(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let action = makeAction(
            payload: .createFleetingNote(DailyLoopNoteCaptureAction(text: trimmed))
        )
        captureStatus = WatchCaptureStatus(
            actionID: action.id,
            text: trimmed,
            state: .queued,
            message: isReachable ? "Saving…" : "Will save when iPhone reconnects"
        )
        append(action)
        persistence.saveCaptureStatus(captureStatus)
        return true
    }

    func retryPending() {
        lastErrorMessage = nil
        if var captureStatus, captureStatus.state == .failed {
            captureStatus.state = .queued
            captureStatus.message = isReachable ? "Retrying…" : "Will retry when iPhone reconnects"
            self.captureStatus = captureStatus
            persistence.saveCaptureStatus(captureStatus)
        }
        inFlightActionID = nil
        acknowledgementTimeoutTask?.cancel()
        sendHeadIfPossible()
    }

    func isTaskPending(_ identity: DailyLoopTaskIdentity) -> Bool {
        pendingActions.contains {
            guard case .setTaskCompletion(let payload) = $0.payload else { return false }
            return payload.identity == identity
        }
    }

    func isHabitPending(_ habitID: Int64) -> Bool {
        pendingActions.contains {
            switch $0.payload {
            case .setHabitProgressAtLeast(let payload):
                return payload.habitID == habitID
            case .setHabitSkipped(let payload):
                return payload.habitID == habitID
            default:
                return false
            }
        }
    }

    private func enqueue(_ payload: DailyLoopWatchActionPayload) {
        append(makeAction(payload: payload))
    }

    private func makeAction(payload: DailyLoopWatchActionPayload) -> DailyLoopWatchAction {
        let action = DailyLoopWatchAction(
            sequence: nextSequence,
            payload: payload
        )
        nextSequence += 1
        persistence.saveNextSequence(nextSequence)
        return action
    }

    private func append(_ action: DailyLoopWatchAction) {
        pendingActions.append(action)
        persistQueue()
        applyOptimistically(action)
        lastErrorMessage = nil
        sendHeadIfPossible()
    }

    private func sendHeadIfPossible() {
        guard connectivity.isReachable,
              inFlightActionID == nil,
              let action = pendingActions.first else {
            return
        }

        inFlightActionID = action.id
        connectivity.sendDailyLoopAction(action) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.scheduleAcknowledgementTimeout(for: action.id)
            case .failure(let error):
                self.inFlightActionID = nil
                self.markDeliveryFailed(actionID: action.id, message: error.localizedDescription)
            }
        }
    }

    private func scheduleAcknowledgementTimeout(for actionID: UUID) {
        acknowledgementTimeoutTask?.cancel()
        acknowledgementTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled,
                  self?.inFlightActionID == actionID else { return }
            self?.inFlightActionID = nil
            self?.sendHeadIfPossible()
        }
    }

    private func handle(_ result: DailyLoopWatchActionResult) {
        guard result.schemaVersion == DailyLoopWatchActionResult.currentSchemaVersion,
              let head = pendingActions.first,
              head.id == result.actionID else {
            return
        }

        acknowledgementTimeoutTask?.cancel()
        inFlightActionID = nil

        if let authoritativeSnapshot = result.authoritativeSnapshot {
            reconcile(with: authoritativeSnapshot)
        }

        switch result.status {
        case .succeeded:
            pendingActions.removeFirst()
            if captureStatus?.actionID == result.actionID {
                captureStatus?.state = .saved
                captureStatus?.message = "Saved on iPhone"
                persistence.saveCaptureStatus(captureStatus)
            }
            lastErrorMessage = nil
            persistQueue()
            sendHeadIfPossible()

        case .failed:
            let message = result.message ?? "Could not save. Tap Retry."
            markDeliveryFailed(actionID: result.actionID, message: message)
        }
    }

    private func markDeliveryFailed(actionID: UUID, message: String) {
        lastErrorMessage = message
        if captureStatus?.actionID == actionID {
            captureStatus?.state = .failed
            captureStatus?.message = message
            persistence.saveCaptureStatus(captureStatus)
        }
    }

    private func reconcile(with snapshot: DailyLoopWatchSnapshot) {
        guard snapshot.schemaVersion == DailyLoopWatchSnapshot.currentSchemaVersion else { return }
        self.snapshot = snapshot
        for action in pendingActions {
            applyOptimistically(action)
        }
        if pendingActions.isEmpty {
            persistence.saveSnapshot(snapshot)
        }
    }

    private func persistQueue() {
        persistence.saveActions(pendingActions)
    }

    private func applyOptimistically(_ action: DailyLoopWatchAction) {
        guard let snapshot else { return }

        var tasks = snapshot.tasks
        var habits = snapshot.habits

        switch action.payload {
        case .setTaskCompletion(let payload):
            tasks = tasks.map { task in
                guard task.identity == payload.identity else { return task }
                return DailyLoopWatchTaskSummary(
                    identity: task.identity,
                    title: task.title,
                    startDate: task.startDate,
                    duration: task.duration,
                    priority: task.priority,
                    recurrenceRule: task.recurrenceRule,
                    isCompleted: payload.isCompleted
                )
            }

        case .setHabitProgressAtLeast(let payload):
            habits = habits.map { habit in
                guard habit.id == payload.habitID else { return habit }
                return DailyLoopWatchHabitSummary(
                    id: habit.id,
                    title: habit.title,
                    current: max(habit.current, payload.minimumValue),
                    target: habit.target,
                    label: habit.label,
                    priority: habit.priority,
                    isSkipped: false
                )
            }

        case .setHabitSkipped(let payload):
            habits = habits.map { habit in
                guard habit.id == payload.habitID else { return habit }
                return DailyLoopWatchHabitSummary(
                    id: habit.id,
                    title: habit.title,
                    current: habit.current,
                    target: habit.target,
                    label: habit.label,
                    priority: habit.priority,
                    isSkipped: payload.isSkipped
                )
            }

        case .createFleetingNote:
            break
        }

        let optimisticSnapshot = DailyLoopWatchSnapshot(
            generatedAt: snapshot.generatedAt,
            tasks: tasks,
            habits: habits
        )
        self.snapshot = optimisticSnapshot
        persistence.saveSnapshot(optimisticSnapshot)
    }
}
