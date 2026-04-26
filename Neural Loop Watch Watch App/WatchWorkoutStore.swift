import Foundation
import Combine
import SwiftUI

@MainActor
final class WatchWorkoutStore: ObservableObject {
    static let shared = WatchWorkoutStore()
    
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
    
    private var actionQueue: [WorkoutWatchAction] = []
    private var isFlushing = false
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot"
    private let queueKey = "com.neuralloop.watch.actionQueue"
    private let connectivityManager: ConnectivityManager
    
    init(connectivityManager: ConnectivityManager = .shared) {
        self.connectivityManager = connectivityManager
        loadFromPersistence()
        loadQueue()
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self = self, let snapshot = snapshot else { return }
                self.reconcile(with: snapshot)
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
    }
    
    // MARK: - Actions
    
    func updateSetValues(exerciseID: String, setID: String, kg: Decimal?, reps: Int?) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let values = WorkoutSetValuesSnapshot(kg: kg, reps: reps)
        let payload = WorkoutWatchActionPayload.updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        enqueueAction(payload: payload)
    }
    
    func toggleSetCompletion(exerciseID: String, setID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let payload = WorkoutWatchActionPayload.toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func addSet(exerciseID: String) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let payload = WorkoutWatchActionPayload.addSet(reference)
        enqueueAction(payload: payload)
    }
    
    func toggleExerciseCompletion(exerciseID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let payload = WorkoutWatchActionPayload.updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func finishWorkout() {
        guard let session = currentSnapshot?.session else { return }
        let payload = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
        let action = WorkoutWatchAction(payload: payload)
        
        // For finish workout, we might want to be more direct, but let's be consistent
        applyOptimisticAction(action)
        
        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.clearStore()
                }
            }
        }
    }

    private func enqueueAction(payload: WorkoutWatchActionPayload) {
        let action = WorkoutWatchAction(payload: payload)
        applyOptimisticAction(action)
        actionQueue.append(action)
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
        // If we already have a newer authoritative one, or if it's somehow stale
        if let current = currentSnapshot, authoritativeSnapshot.timestamp < current.timestamp {
            // Ideally we compare timestamps, but let's trust the latest from iPhone for now
            // as it's the authoritative source.
        }
        
        // Remove acknowledged actions from queue
        if let lastID = authoritativeSnapshot.lastProcessedActionID {
            if let index = actionQueue.firstIndex(where: { $0.id == lastID }) {
                actionQueue.removeSubrange(0...index)
                saveQueue()
            }
        }
        
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
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: queueKey)
    }
}
