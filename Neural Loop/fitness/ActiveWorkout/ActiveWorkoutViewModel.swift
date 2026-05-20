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
    @Published var restEndsAt: Date?
    @Published var availableExercises: [ExerciseLibraryItem] = []
    @Published var isLoadingCatalog = false
    
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
        
        // Restore timer state from draft if valid
        if let restEndDate = draft.restEndDate, let restTotal = draft.restTotalSeconds {
            let remaining = Int(restEndDate.timeIntervalSince(Date()))
            if remaining > 0 {
                self.restTimerSeconds = remaining
                self.isTimerRunning = true
                self.restEndsAt = restEndDate
                startTimer(seconds: remaining)
            }
        }
    }
    
    func clearDraft() {
        persistenceManager.clear(routineID: draft.routineID)
    }

    private func persistDraft() {
        draft.updatedAt = Date()
        draft.revision += 1
        persistenceManager.save(draft: draft)
        onDraftChange?(draft)
        sendSnapshotToWatch()
        updateLiveActivity()
    }

    func sendSnapshotToWatch() {
        let restEnd = isTimerRunning ? restEndsAt : nil
        let restTotal = isTimerRunning ? restTimerSeconds : nil
        let snapshot = draft.watchSnapshot(
            lastProcessedActionID: nil,
            restEndDate: restEnd,
            restTotalSeconds: restTotal
        )
        connectivityProvider?.sendWorkoutSnapshot(snapshot, completion: nil)
    }

    private func updateLiveActivity() {
        let restEnd = isTimerRunning ? restEndsAt : nil
        let restTotal = isTimerRunning ? restTimerSeconds : nil
        let snapshot = draft.watchSnapshot(
            lastProcessedActionID: nil,
            restEndDate: restEnd,
            restTotalSeconds: restTotal
        )
        WorkoutLiveActivityManager.shared.updateActivity(
            snapshot: snapshot,
            restEndDate: restEnd,
            restTotalSeconds: restTotal
        )
    }

    func apply(watchAction action: WorkoutWatchAction) async {
        // Validate session ID
        guard actionSessionMatchesDraft(action: action.payload) else {
            sendSnapshotToWatch()
            return
        }
        
        guard !draft.processedWatchActionIDs.contains(action.id) else {
            sendSnapshotToWatch()
            return
        }
        
        guard action.sequence == draft.lastProcessedWatchSequence + 1 || action.sequence == 0 else {
            // Sequence mismatch: reject out-of-order action and resync
            sendSnapshotToWatch()
            return
        }
        switch action.payload {
        case .requestSnapshot:
            sendSnapshotToWatch()
            
        case .toggleSetCompletion(let completionAction):
            draft.apply(watchAction: action)
            persistDraft()
            
            if completionAction.isCompleted {
                if let exerciseID = resolveExerciseID(completionAction.reference.exerciseID, routineExerciseID: completionAction.reference.routineExerciseID),
                   let exercise = draft.exercises.first(where: { $0.id == exerciseID }),
                   let restSeconds = exercise.restSeconds, restSeconds > 0 {
                    startTimer(seconds: restSeconds)
                }
            } else {
                stopTimer()
            }

        case .cancelRestTimer:
            draft.apply(watchAction: action) 
            stopTimer()

        case .finishWorkout:
            do {
                try await finalizer.finalize(draft: draft)
                
                draft.markProcessed(action: action)
                connectivityProvider?.clearWorkoutSnapshot(sessionID: draft.watchSessionPointer.id, reason: .finalized)
                
                let result = WorkoutFinalizedResult(sessionID: draft.watchSessionPointer.id, success: true)
                connectivityProvider?.sendWorkoutFinalizedResult(result, completion: nil)
                // End Live Activity on watch-initiated finish
                let finalSnapshot = draft.watchSnapshot()
                WorkoutLiveActivityManager.shared.endActivity(finalSnapshot: finalSnapshot)
                onFinish?()
            } catch {
                let result = WorkoutFinalizedResult(sessionID: draft.watchSessionPointer.id, success: false, errorMessage: error.localizedDescription)
                connectivityProvider?.sendWorkoutFinalizedResult(result, completion: nil)
            }

        default:
            draft.apply(watchAction: action)
            persistDraft()
        }
    }

    private func actionSessionMatchesDraft(action: WorkoutWatchActionPayload) -> Bool {
        return action.session.id == draft.watchSessionPointer.id
    }

    /// Resolves an exercise ID from a watch action reference.
    /// Prefers the numeric routineExerciseID (RoutineExercise.id / WorkoutExerciseCardState.id)
    /// which is what draft.exercises uses for its .id field.
    /// Falls back to parsing the string exerciseID directly for backward compatibility.
    private func resolveExerciseID(_ stringID: String, routineExerciseID: Int64?) -> Int64? {
        if let routineExerciseID { return routineExerciseID }
        return Int64(stringID)
    }

    func finishWorkout() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            try await finalizer.finalize(draft: draft)
            connectivityProvider?.clearWorkoutSnapshot(sessionID: draft.watchSessionPointer.id, reason: .finalized)
            // Send finalization success to watch
            let result = WorkoutFinalizedResult(sessionID: draft.watchSessionPointer.id, success: true)
            connectivityProvider?.sendWorkoutFinalizedResult(result, completion: nil)
            // End Live Activity
            let finalSnapshot = draft.watchSnapshot()
            WorkoutLiveActivityManager.shared.endActivity(finalSnapshot: finalSnapshot)
            onFinish?()
        } catch {
            errorMessage = error.localizedDescription
            // Send finalization failure to watch
            let result = WorkoutFinalizedResult(sessionID: draft.watchSessionPointer.id, success: false, errorMessage: error.localizedDescription)
            connectivityProvider?.sendWorkoutFinalizedResult(result, completion: nil)
        }
        
        isLoading = false
    }
    
    func addSet(to exerciseID: Int64, id: UUID? = nil) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextSetNumber = (draft.exercises[index].sets.map(\.setNumber).max() ?? 0) + 1
        let lastReps = draft.exercises[index].sets.last?.repsText ?? ""
        let lastWeight = draft.exercises[index].sets.last?.weightText ?? ""
        let lastDuration = draft.exercises[index].sets.last?.durationText ?? ""
        let lastDistance = draft.exercises[index].sets.last?.distanceText ?? ""
        let lastCalories = draft.exercises[index].sets.last?.caloriesText ?? ""
        
        let newSet = WorkoutSetDraft(
            id: id ?? UUID(),
            setNumber: nextSetNumber,
            weightText: lastWeight,
            repsText: lastReps,
            durationText: lastDuration,
            distanceText: lastDistance,
            caloriesText: lastCalories
        )
        draft.exercises[index].sets.append(newSet)
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
        } else {
            stopTimer()
        }
    }

    // MARK: - Exercise Catalog & Adding Exercises

    var currentExerciseIDs: Set<Int64> {
        Set(draft.exercises.map { $0.exercise.id })
    }

    func loadExerciseCatalog() async {
        guard availableExercises.isEmpty, !isLoadingCatalog else { return }
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }

        do {
            async let equipmentRows = db.fetchAllEquipment()
            async let exerciseRows = db.fetchAllExercisesWithMuscles()

            let (equipment, exercises) = try await (equipmentRows, exerciseRows)
            availableExercises = WorkoutCatalogMapper.makeLibraryItems(
                equipment: equipment,
                exercises: exercises
            )
        } catch {
            // Catalog load failure is non-blocking; the Add Exercise button stays disabled
            print("Error loading exercise catalog: \(error)")
        }
    }

    func addExercises(from selections: [ExerciseLibraryItem]) {
        let existingIDs = currentExerciseIDs
        let newItems = selections.filter { !existingIDs.contains($0.id) }
        guard !newItems.isEmpty else { return }

        for item in newItems {
            // Use a negative ID to avoid collisions with real routine_exercise IDs.
            // Each new ad-hoc exercise gets a unique negative ID based on exercise ID.
            let syntheticID = -item.id

            let defaultSet = WorkoutSetDraft(setNumber: 1)
            let cardState = WorkoutExerciseCardState(
                id: syntheticID,
                exercise: item,
                sets: [defaultSet]
            )
            draft.exercises.append(cardState)
        }
        persistDraft()
    }

    private func startTimer(seconds: Int) {
        timerCancellable?.cancel()
        restTimerSeconds = seconds
        isTimerRunning = true
        restEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        
        // Sync to draft for persistence
        draft.restEndDate = restEndsAt
        draft.restTotalSeconds = seconds
        persistDraft()

        // Push rest state to Live Activity and Watch immediately
        updateLiveActivity()
        sendSnapshotToWatch()
        
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
        restEndsAt = nil
        
        // Sync to draft for persistence
        draft.restEndDate = nil
        draft.restTotalSeconds = nil
        persistDraft()
        
        // Push updated state (rest ended) to Live Activity and Watch
        updateLiveActivity()
        sendSnapshotToWatch()
    }
}
