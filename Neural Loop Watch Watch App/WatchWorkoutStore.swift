import Foundation
import Combine
import SwiftUI
import WidgetKit

/// Coordination payload set by WatchSetEntryView after a set is completed,
/// observed by WatchExerciseDetailView to present the rest timer.
struct CompletedSetInfo: Equatable {
    let exerciseID: String
    let setID: String
    let restDurationSeconds: Int
}

@MainActor
final class WatchWorkoutStore: ObservableObject {
    static let shared = WatchWorkoutStore()
    
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
    
    // MARK: - Rest Timer Navigation (Plan 527)
    /// Set by WatchSetEntryView; observed by WatchExerciseDetailView.
    @Published var lastCompletedSetInfo: CompletedSetInfo?
    
    // MARK: - End Workout State (Plan 528)
    @Published var isFinishing: Bool = false
    @Published var finishError: String?
    
    enum WatchWorkoutSyncState: Equatable {
        case live
        case offlineQueuedEdits(count: Int)
        case syncing
        case finishing
        case finishFailed(String)
        case stale
        case endedRemotely
        case finishQueuedOffline
    }

    var syncState: WatchWorkoutSyncState {
        if isSnapshotStale { return .stale }
        if let error = finishError {
            if error.contains("queued") {
                return .finishQueuedOffline
            }
            return .finishFailed(error)
        }
        if isFinishing { return .finishing }
        if isFlushing { return .syncing }
        if pendingActionCount > 0 { return .offlineQueuedEdits(count: pendingActionCount) }
        return .live
    }
    
    // MARK: - Queue Visibility (Plan 529)
    @Published var pendingActionCount: Int = 0
    
    private var actionQueue: [WorkoutWatchAction] = []
    private(set) var isFlushing = false
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot"
    private let queueKey = "com.neuralloop.watch.actionQueue"
    let connectivityManager: ConnectivityManager
    
    init(connectivityManager: ConnectivityManager = .shared) {
        self.connectivityManager = connectivityManager
        loadFromPersistence()
        loadQueue()
        pendingActionCount = actionQueue.count
        connectivityManager.checkApplicationContext()
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                if let snapshot {
                    self.reconcile(with: snapshot)
                } else if self.currentSnapshot != nil {
                    // This fallback handles if the iPhone cleared the active workout
                    self.clearStore()
                }
            }
            .store(in: &cancellables)
            
        connectivityManager.clearedWorkoutHandler = { [weak self] cleared in
            guard let self = self else { return }
            if self.currentSnapshot?.session.id == cleared.sessionID {
                self.clearStore()
                // If it was cancelled on phone or replaced, we could potentially show an alert
            }
        }
            
        connectivityManager.$isReachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReachable in
                if isReachable {
                    self?.flushQueue()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to finalization results from iPhone
        connectivityManager.finalizationHandler = { [weak self] result in
            guard let self else { return }
            self.handleFinalizationResult(result)
        }
    }
    
    // MARK: - Finalization Result Handling
    
    private func handleFinalizationResult(_ result: WorkoutFinalizedResult) {
        guard let currentSnapshot, currentSnapshot.session.id == result.sessionID else { return }
        
        if result.success {
            clearStore()
        } else {
            isFinishing = false
            finishError = result.errorMessage ?? "Workout could not be saved"
        }
    }
    
    // MARK: - Actions
    
    func updateSetValues(exerciseID: String, setID: String, kg: Decimal?, reps: Int?) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID, setID: setID)
        let values = WorkoutSetValuesSnapshot(kg: kg, reps: reps)
        let payload = WorkoutWatchActionPayload.updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        enqueueAction(payload: payload)
    }
    
    func toggleSetCompletion(exerciseID: String, setID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID, setID: setID)
        let payload = WorkoutWatchActionPayload.toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func addSet(exerciseID: String) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID)
        let payload = WorkoutWatchActionPayload.addSet(reference)
        enqueueAction(payload: payload)
    }
    
    func toggleExerciseCompletion(exerciseID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID)
        let payload = WorkoutWatchActionPayload.updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func finishWorkout() {
        guard let session = currentSnapshot?.session else { return }
        guard !isFinishing else { return }
        isFinishing = true
        finishError = nil
        
        let payload = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
        enqueueAction(payload: payload)
        
        if !connectivityManager.isReachable {
            finishError = "Workout finish queued. Open iPhone to sync."
            isFinishing = false
        }
    }
    
    func retryFinish() {
        guard !isFinishing else { return }
        isFinishing = true
        finishError = nil
        // A finish action is likely already in the queue, just try flushing again.
        flushQueue()
        
        if !connectivityManager.isReachable {
            finishError = "Workout finish queued. Open iPhone to sync."
            isFinishing = false
        }
    }

    private var lastGeneratedSequence: Int {
        return actionQueue.map(\.sequence).max() ?? (currentSnapshot?.lastProcessedWatchSequence ?? 0)
    }

    private func enqueueAction(payload: WorkoutWatchActionPayload) {
        let sequence = lastGeneratedSequence + 1
        let action = WorkoutWatchAction(id: UUID(), timestamp: Date(), sequence: sequence, payload: payload)
        applyOptimisticAction(action)
        actionQueue.append(action)
        pendingActionCount = actionQueue.count
        saveQueue()
        flushQueue()
    }

    private func applyOptimisticAction(_ action: WorkoutWatchAction) {
        guard var snapshot = currentSnapshot else { return }
        reconcileApply(action, to: &snapshot)
        self.currentSnapshot = snapshot
        saveToPersistence()
        persistDisplayStateAndReloadWidgets()
    }

    private func reconcile(with authoritativeSnapshot: ActiveWorkoutSnapshot) {
        // Session replacement check
        if let current = currentSnapshot,
           current.session.id != authoritativeSnapshot.session.id {
            actionQueue.removeAll()
            saveQueue()
            pendingActionCount = 0
            self.currentSnapshot = authoritativeSnapshot
            saveToPersistence()
            persistDisplayStateAndReloadWidgets(
                restEndDate: authoritativeSnapshot.restEndDate,
                restTotalSeconds: authoritativeSnapshot.restTotalSeconds
            )
            return
        }
        
        // Revision check
        if let current = currentSnapshot, authoritativeSnapshot.revision < current.revision {
            return
        }
        
        // Remove acknowledged actions from queue using sequence number
        actionQueue.removeAll { $0.sequence <= authoritativeSnapshot.lastProcessedWatchSequence }
        
        pendingActionCount = actionQueue.count
        
        var reconciledSnapshot = authoritativeSnapshot
        
        // Re-apply remaining actions in FIFO order
        for action in actionQueue {
            reconcileApply(action, to: &reconciledSnapshot)
        }
        
        self.currentSnapshot = reconciledSnapshot
        saveToPersistence()
        persistDisplayStateAndReloadWidgets(
            restEndDate: reconciledSnapshot.restEndDate,
            restTotalSeconds: reconciledSnapshot.restTotalSeconds
        )
    }

    private func reconcileApply(_ action: WorkoutWatchAction, to snapshot: inout ActiveWorkoutSnapshot) {
        switch action.payload {
        case .updateSetValues(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }),
               let setIndex = snapshot.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == action.reference.setID }) {
                if let kg = action.values.kg {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.kg = kg
                }
                if let reps = action.values.reps {
                    snapshot.exercises[exerciseIndex].sets[setIndex].values.reps = reps
                }
            }
        case .toggleSetCompletion(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }),
               let setIndex = snapshot.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == action.reference.setID }) {
                snapshot.exercises[exerciseIndex].sets[setIndex].isCompleted = action.isCompleted
            }
        case .addSet(let reference):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == reference.exerciseID }) {
                let newSet = SetSnapshot(
                    id: action.id.uuidString, // Use action ID as temp set ID
                    setNumber: snapshot.exercises[exerciseIndex].sets.count + 1,
                    values: WorkoutSetValuesSnapshot(),
                    isCompleted: false
                )
                snapshot.exercises[exerciseIndex].sets.append(newSet)
            }
        case .updateExerciseCompletion(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }) {
                snapshot.exercises[exerciseIndex].isCompleted = action.isCompleted
                for i in 0..<snapshot.exercises[exerciseIndex].sets.count {
                    snapshot.exercises[exerciseIndex].sets[i].isCompleted = action.isCompleted
                }
            }
        default:
            break
        }
    }

    func flushQueue() {
        guard !isFlushing, !actionQueue.isEmpty, connectivityManager.isReachable else { return }
        isFlushing = true
        
        sendNextPending(after: nil)
    }

    private func sendNextPending(after lastID: UUID?) {
        let remaining = actionQueue
        let startIndex: Int
        if let lastID = lastID, let index = remaining.firstIndex(where: { $0.id == lastID }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        
        guard startIndex < remaining.count, connectivityManager.isReachable else {
            isFlushing = false
            return
        }
        
        let action = remaining[startIndex]
        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case .success = result {
                    self.sendNextPending(after: action.id)
                } else {
                    self.isFlushing = false
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(actionQueue)
            UserDefaults.standard.set(data, forKey: queueKey)
        } catch {
            print("Failed to save action queue: \(error)")
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return }
        do {
            self.actionQueue = try JSONDecoder().decode([WorkoutWatchAction].self, from: data)
        } catch {
            print("Failed to load action queue: \(error)")
        }
    }
    
    private func saveToPersistence() {
        guard let currentSnapshot = currentSnapshot else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        do {
            let data = try JSONEncoder().encode(currentSnapshot)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save snapshot to persistence: \(error)")
        }
    }
    
    private func loadFromPersistence() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data)
            self.currentSnapshot = snapshot
        } catch {
            print("Failed to load snapshot from persistence: \(error)")
        }
    }
    
    func clearStore() {
        self.currentSnapshot = nil
        self.actionQueue.removeAll()
        self.pendingActionCount = 0
        self.lastCompletedSetInfo = nil
        self.isFinishing = false
        self.finishError = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: queueKey)
        clearDisplayStateAndReloadWidgets()
    }
    
    // MARK: - Stale Draft Detection (Plan 529)
    
    var isSnapshotStale: Bool {
        guard let startedAt = currentSnapshot?.startedAt else { return false }
        return Date().timeIntervalSince(startedAt) > 24 * 3600
    }
    
    var staleSnapshotAge: String? {
        guard let startedAt = currentSnapshot?.startedAt else { return nil }
        let hours = Int(Date().timeIntervalSince(startedAt) / 3600)
        if hours < 24 { return nil }
        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
    
    func discardStaleWorkout() {
        clearStore()
    }

    // MARK: - Complication Display State Persistence (Tasks 8 + 9)

    private static let complicationWidgetKind = "WorkoutComplicationWidget"

    /// Shared App Group suite defaults so the watch widget extension can read the same data.
    private static let suiteDefaults = UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite)

    /// Persists the current snapshot as a `WorkoutDisplayState` for the complication widget
    /// and triggers a timeline reload.
    /// - Parameters:
    ///   - restEndDate: The rest timer end date (if resting).
    ///   - restTotalSeconds: Total rest duration in seconds (if resting).
    func persistDisplayStateAndReloadWidgets(restEndDate: Date? = nil, restTotalSeconds: Int? = nil) {
        guard let snapshot = currentSnapshot else {
            clearDisplayStateAndReloadWidgets()
            return
        }
        let displayState = snapshot.displayState(restEndDate: restEndDate, restTotalSeconds: restTotalSeconds)
        guard let defaults = Self.suiteDefaults else {
            print("WatchWorkoutStore: App Group suite defaults unavailable")
            return
        }
        do {
            let data = try JSONEncoder().encode(displayState)
            defaults.set(data, forKey: WorkoutDisplayState.userDefaultsKey)
        } catch {
            print("WatchWorkoutStore: Failed to persist display state: \(error)")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: Self.complicationWidgetKind)
    }

    /// Clears persisted display state and reloads widget timelines.
    private func clearDisplayStateAndReloadWidgets() {
        Self.suiteDefaults?.removeObject(forKey: WorkoutDisplayState.userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.complicationWidgetKind)
    }
}
