import Foundation
import Combine
import SwiftUI

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
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                if let snapshot {
                    self.reconcile(with: snapshot)
                } else if self.currentSnapshot != nil {
                    // iPhone cleared the active workout (Plan 528)
                    self.clearStore()
                }
            }
            .store(in: &cancellables)
            
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
        
        // Flush pending edits first, then send finish
        flushQueueThenFinish(session: session)
    }
    
    func retryFinish() {
        guard let session = currentSnapshot?.session else { return }
        isFinishing = true
        finishError = nil
        flushQueueThenFinish(session: session)
    }
    
    private func flushQueueThenFinish(session: WorkoutSessionPointer) {
        guard !actionQueue.isEmpty, connectivityManager.isReachable else {
            sendFinishAction(session: session)
            return
        }
        
        flushQueue()
        pollQueueDrain(session: session, startTime: Date())
    }
    
    private func pollQueueDrain(session: WorkoutSessionPointer, startTime: Date) {
        if actionQueue.isEmpty {
            sendFinishAction(session: session)
            return
        }
        
        if Date().timeIntervalSince(startTime) > 10 {
            // Timeout reached, queue hasn't drained. Do not finish to avoid losing data.
            self.finishError = "Sync timeout. Try again."
            self.isFinishing = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pollQueueDrain(session: session, startTime: startTime)
        }
    }
    
    private func sendFinishAction(session: WorkoutSessionPointer) {
        let payload = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
        let action = WorkoutWatchAction(payload: payload)
        applyOptimisticAction(action)
        
        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .failure = result {
                    self.finishError = "Could not reach iPhone"
                    self.isFinishing = false
                } else {
                    // it should be clearned now
                    self.clearStore()
                    // On success: start a timeout waiting for workoutFinalized message from iPhone
                    // DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                    //     guard let self, self.isFinishing else { return }
                    //     self.finishError = "No response from iPhone. Try again."
                    //     self.isFinishing = false
                    // }
                }
            }
        }
    }

    private func enqueueAction(payload: WorkoutWatchActionPayload) {
        let action = WorkoutWatchAction(payload: payload)
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
    }

    private func reconcile(with authoritativeSnapshot: ActiveWorkoutSnapshot) {
        // If the incoming snapshot is for a different session, replace entirely
        if let current = currentSnapshot,
           current.session.id != authoritativeSnapshot.session.id {
            actionQueue.removeAll()
            saveQueue()
            pendingActionCount = 0
            self.currentSnapshot = authoritativeSnapshot
            saveToPersistence()
            return
        }
        
        // Remove acknowledged actions from queue
        if let lastID = authoritativeSnapshot.lastProcessedActionID {
            if let index = actionQueue.firstIndex(where: { $0.id == lastID }) {
                actionQueue.removeSubrange(0...index)
                saveQueue()
            }
        }
        
        pendingActionCount = actionQueue.count
        
        var reconciledSnapshot = authoritativeSnapshot
        
        // Re-apply remaining actions in FIFO order
        for action in actionQueue {
            reconcileApply(action, to: &reconciledSnapshot)
        }
        
        self.currentSnapshot = reconciledSnapshot
        saveToPersistence()
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
}
