import Foundation
import Combine
import SwiftUI

@MainActor
final class WatchWorkoutStore: ObservableObject {
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
    
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot"
    private let connectivityManager: ConnectivityManager
    
    init(connectivityManager: ConnectivityManager = .shared) {
        self.connectivityManager = connectivityManager
        loadFromPersistence()
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self = self, let snapshot = snapshot else { return }
                self.currentSnapshot = snapshot
                self.saveToPersistence()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    func updateSetValues(exerciseID: String, setID: String, kg: Decimal?, reps: Int?) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let values = WorkoutSetValuesSnapshot(kg: kg, reps: reps)
        let action = WorkoutWatchActionPayload.updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        connectivityManager.sendWorkoutAction(action)
    }
    
    func toggleSetCompletion(exerciseID: String, setID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let action = WorkoutWatchActionPayload.toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        connectivityManager.sendWorkoutAction(action)
    }
    
    func addSet(exerciseID: String) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let action = WorkoutWatchActionPayload.addSet(reference)
        connectivityManager.sendWorkoutAction(action)
    }
    
    func toggleExerciseCompletion(exerciseID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let action = WorkoutWatchActionPayload.updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        connectivityManager.sendWorkoutAction(action)
    }
    
    func finishWorkout() {
        guard let session = currentSnapshot?.session else { return }
        let action = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
        connectivityManager.sendWorkoutAction(action)
        clearStore()
    }
    
    // MARK: - Persistence
    
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
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
