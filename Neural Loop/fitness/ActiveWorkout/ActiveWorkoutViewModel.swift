import Combine
import Foundation
import SwiftUI

@MainActor
class ActiveWorkoutViewModel: ObservableObject, Identifiable {
    var id: Int64 { draft.routineID }
    @Published var draft: ActiveWorkoutDraft
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var restTimerSeconds: Int = 0
    @Published var isTimerRunning: Bool = false
    
    let db: WorkoutDataManaging
    var onDraftChange: ((ActiveWorkoutDraft) -> Void)?
    var onFinish: (() -> Void)?
    private let persistenceManager: WorkoutDraftPersistenceManager
    private let connectivityProvider: WorkoutConnectivityProviding?
    private let finalizer: WorkoutSessionFinalizing
    private var timerCancellable: AnyCancellable?
    
    init(
        draft: ActiveWorkoutDraft,
        db: WorkoutDataManaging,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager(),
        connectivityProvider: WorkoutConnectivityProviding? = nil,
        finalizer: WorkoutSessionFinalizing? = nil,
        onDraftChange: ((ActiveWorkoutDraft) -> Void)? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.draft = draft
        self.db = db
        self.persistenceManager = persistenceManager
        self.connectivityProvider = connectivityProvider
        self.finalizer = finalizer ?? WorkoutSessionFinalizer(db: db, persistenceManager: persistenceManager)
        self.onDraftChange = onDraftChange
        self.onFinish = onFinish
    }
    
    func clearDraft() {
        persistenceManager.clear(routineID: draft.routineID)
    }

    private func persistDraft() {
        draft.updatedAt = Date()
        persistenceManager.save(draft: draft)
        onDraftChange?(draft)
        sendSnapshotToWatch()
    }

    func sendSnapshotToWatch() {
        let snapshot = draft.watchSnapshot()
        connectivityProvider?.sendWorkoutSnapshot(snapshot, completion: nil)
    }

    func apply(watchAction: WorkoutWatchActionPayload) async {
        // Validate session ID
        guard actionSessionMatchesDraft(action: watchAction) else { return }

        switch watchAction {
        case .requestSnapshot:
            sendSnapshotToWatch()
            
        case .updateSetValues(let action):
            guard let exerciseID = Int64(action.reference.exerciseID),
                  let setUUID = UUID(uuidString: action.reference.setID) else { return }
            
            if let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
               let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setUUID }) {
                
                var changed = false
                if let weight = action.values.kg {
                    draft.exercises[exerciseIndex].sets[setIndex].weightText = "\(weight)"
                    changed = true
                }
                if let reps = action.values.reps {
                    draft.exercises[exerciseIndex].sets[setIndex].repsText = "\(reps)"
                    changed = true
                }
                
                if changed {
                    persistDraft()
                }
            }
            
        case .toggleSetCompletion(let action):
            guard let exerciseID = Int64(action.reference.exerciseID),
                  let setUUID = UUID(uuidString: action.reference.setID) else { return }
            
            // Avoid redundant toggles if watch state already matches
            if let exercise = draft.exercises.first(where: { $0.id == exerciseID }),
               let set = exercise.sets.first(where: { $0.id == setUUID }),
               set.isCompleted != action.isCompleted {
                toggleSetCompletion(exerciseID: exerciseID, setID: setUUID)
            }
            
        case .addSet(let reference):
            guard let exerciseID = Int64(reference.exerciseID) else { return }
            addSet(to: exerciseID)
            
        case .updateExerciseCompletion(let action):
            guard let exerciseID = Int64(action.reference.exerciseID) else { return }
            completeExercise(exerciseID: exerciseID, isCompleted: action.isCompleted)
            
        case .finishWorkout:
            await finishWorkout()
        }
    }

    private func actionSessionMatchesDraft(action: WorkoutWatchActionPayload) -> Bool {
        return action.session.id == draft.watchSessionPointer.id
    }

    func finishWorkout() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            try await finalizer.finalize(draft: draft)
            onFinish?()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addSet(to exerciseID: Int64) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextSetNumber = (draft.exercises[index].sets.map(\.setNumber).max() ?? 0) + 1
        let lastReps = draft.exercises[index].sets.last?.repsText ?? ""
        let lastWeight = draft.exercises[index].sets.last?.weightText ?? ""
        let lastDuration = draft.exercises[index].sets.last?.durationText ?? ""
        let lastDistance = draft.exercises[index].sets.last?.distanceText ?? ""
        let lastCalories = draft.exercises[index].sets.last?.caloriesText ?? ""
        
        draft.exercises[index].sets.append(WorkoutSetDraft(
            setNumber: nextSetNumber,
            weightText: lastWeight,
            repsText: lastReps,
            durationText: lastDuration,
            distanceText: lastDistance,
            caloriesText: lastCalories
        ))
        persistDraft()
    }

    func completeExercise(exerciseID: Int64, isCompleted: Bool) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        for i in 0..<draft.exercises[index].sets.count {
            draft.exercises[index].sets[i].isCompleted = isCompleted
        }
        persistDraft()
    }
    
    func updateWeight(for exerciseID: Int64, setID: UUID, weightText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].weightText = weightText
        persistDraft()
    }
    
    func updateReps(for exerciseID: Int64, setID: UUID, repsText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].repsText = repsText
        persistDraft()
    }

    func updateDuration(for exerciseID: Int64, setID: UUID, durationText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].durationText = durationText
        persistDraft()
    }

    func updateDistance(for exerciseID: Int64, setID: UUID, distanceText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].distanceText = distanceText
        persistDraft()
    }

    func updateCalories(for exerciseID: Int64, setID: UUID, caloriesText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].caloriesText = caloriesText
        persistDraft()
    }

    func toggleSetCompletion(exerciseID: Int64, setID: UUID) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        
        draft.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
        persistDraft()
        
        if draft.exercises[exerciseIndex].sets[setIndex].isCompleted {
            if let restSeconds = draft.exercises[exerciseIndex].restSeconds, restSeconds > 0 {
                startTimer(seconds: restSeconds)
            }
        }
    }

    private func startTimer(seconds: Int) {
        timerCancellable?.cancel()
        restTimerSeconds = seconds
        isTimerRunning = true
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    if self.restTimerSeconds > 0 {
                        self.restTimerSeconds -= 1
                    }
                    
                    if self.restTimerSeconds == 0 {
                        self.stopTimer()
                    }
                }
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        isTimerRunning = false
        restTimerSeconds = 0
    }
}
