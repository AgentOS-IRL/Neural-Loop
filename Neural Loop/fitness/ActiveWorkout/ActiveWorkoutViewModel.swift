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
    
    let db: any WorkoutCatalogReading & WorkoutLaunchHistoryReading & WorkoutFinalizationPersisting & ExerciseProgressionReading
    var onDraftChange: ((ActiveWorkoutDraft) -> Void)?
    var onFinish: (() -> Void)?
    private let runtime: any WorkoutSessionRuntimeCoordinating
    private var timerCancellable: AnyCancellable?
    
    init(
        draft: ActiveWorkoutDraft,
        db: any WorkoutCatalogReading & WorkoutLaunchHistoryReading & WorkoutFinalizationPersisting & ExerciseProgressionReading,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager(),
        connectivityProvider: WorkoutConnectivityProviding? = nil,
        finalizer: WorkoutSessionFinalizing? = nil,
        runtime: (any WorkoutSessionRuntimeCoordinating)? = nil,
        onDraftChange: ((ActiveWorkoutDraft) -> Void)? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.draft = draft
        self.db = db
        let resolvedFinalizer = finalizer ?? WorkoutSessionFinalizer(
            db: db,
            persistenceManager: persistenceManager
        )
        self.runtime = runtime ?? WorkoutSessionRuntimeCoordinator(
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider ?? NoopWorkoutConnectivityProvider.shared,
            finalizer: resolvedFinalizer
        )
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
        runtime.persistenceManager.clear(routineID: draft.routineID)
    }

    private func persistDraft(acknowledging actionID: UUID? = nil) {
        draft.updatedAt = Date()
        draft.revision += 1
        runtime.publish(draft, acknowledging: actionID)
        onDraftChange?(draft)
    }

    func sendSnapshotToWatch() {
        runtime.publish(draft, acknowledging: nil)
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

            if completionAction.isCompleted {
                if let exerciseID = resolveExerciseID(completionAction.reference.exerciseID, routineExerciseID: completionAction.reference.routineExerciseID),
                   let exercise = draft.exercises.first(where: { $0.id == exerciseID }),
                   let setID = UUID(uuidString: completionAction.reference.setID),
                   exercise.sets.first(where: { $0.id == setID })?.isCompleted == true,
                   let restSeconds = exercise.restSeconds, restSeconds > 0 {
                    startTimer(seconds: restSeconds, acknowledging: action.id)
                } else {
                    persistDraft(acknowledging: action.id)
                }
            } else {
                stopTimer(acknowledging: action.id)
            }

        case .cancelRestTimer:
            draft.apply(watchAction: action)
            stopTimer(acknowledging: action.id)

        case .finishWorkout:
            do {
                draft.markProcessed(action: action)
                try await runtime.finish(draft)
                onFinish?()
            } catch {
                errorMessage = error.localizedDescription
            }

        default:
            draft.apply(watchAction: action)
            persistDraft(acknowledging: action.id)
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
            try await runtime.finish(draft)
            onFinish?()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addSet(to exerciseID: Int64, id: UUID? = nil) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let workingSets = draft.exercises[index].sets.filter { $0.setType == .working }
        let nextSetNumber = (workingSets.map(\.setNumber).max() ?? 0) + 1
        let lastSet = workingSets.last
        
        let newSet = WorkoutSetDraft(
            id: id ?? UUID(),
            setNumber: nextSetNumber,
            setType: .working,
            previousValues: lastSet?.previousValues,
            suggestedValues: lastSet?.suggestedValues,
            suggestionReason: lastSet?.suggestionReason
        )
        draft.exercises[index].sets.append(newSet)
        persistDraft()
    }

    func completeExercise(exerciseID: Int64, isCompleted: Bool) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if isCompleted {
            let exercise = draft.exercises[index]
            let allEntered = exercise.sets.allSatisfy { set in
                exercise.exercise.isRepBased
                    ? set.hasRequiredStrengthValues
                    : set.hasRequiredCardioValues
            }
            guard allEntered else {
                errorMessage = "Enter values or use suggestions for every set first."
                return
            }
        }
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
        
        let set = draft.exercises[exerciseIndex].sets[setIndex]
        if !set.isCompleted {
            let canComplete = draft.exercises[exerciseIndex].exercise.isRepBased
                ? set.hasRequiredStrengthValues
                : set.hasRequiredCardioValues
            guard canComplete else {
                errorMessage = "Enter values or use the suggestion before completing this set."
                return
            }
        }

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

    func addExercises(from selections: [ExerciseLibraryItem]) async {
        let existingIDs = currentExerciseIDs
        let newItems = selections.filter { !existingIDs.contains($0.id) }
        guard !newItems.isEmpty else { return }

        var addedStates: [WorkoutExerciseCardState] = []
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
            addedStates.append(cardState)
        }

        let loader = WorkoutSessionLoader(db: db)
        let statesWithHistory = await loader.loadHistory(for: addedStates, routineID: nil)
        draft.exercises.append(contentsOf: statesWithHistory)
        persistDraft()
    }

    func useSuggestion(exerciseID: Int64, setID: UUID) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }),
              let values = draft.exercises[exerciseIndex].sets[setIndex].suggestedValues else { return }

        apply(values: values, to: &draft.exercises[exerciseIndex].sets[setIndex])
        persistDraft()
    }

    func applyAllSuggestions(exerciseID: Int64) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        for setIndex in draft.exercises[exerciseIndex].sets.indices {
            guard !draft.exercises[exerciseIndex].sets[setIndex].isCompleted,
                  let values = draft.exercises[exerciseIndex].sets[setIndex].suggestedValues else { continue }
            apply(values: values, to: &draft.exercises[exerciseIndex].sets[setIndex])
        }
        persistDraft()
    }

    private func apply(values: WorkoutDraftValues, to set: inout WorkoutSetDraft) {
        if let reps = values.reps {
            set.repsText = String(reps)
            set.weightText = values.weight.map(NumericFormatter.format) ?? ""
        }
        if let duration = values.durationMinutes { set.durationText = NumericFormatter.format(duration) }
        if let distance = values.distanceKilometers { set.distanceText = NumericFormatter.format(distance) }
        if let calories = values.calories { set.caloriesText = NumericFormatter.format(calories) }
    }

    private func startTimer(seconds: Int, acknowledging actionID: UUID? = nil) {
        timerCancellable?.cancel()
        restTimerSeconds = seconds
        isTimerRunning = true
        restEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        
        // Sync to draft for persistence
        draft.restEndDate = restEndsAt
        draft.restTotalSeconds = seconds
        persistDraft(acknowledging: actionID)
        
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

    func stopTimer(acknowledging actionID: UUID? = nil) {
        timerCancellable?.cancel()
        isTimerRunning = false
        restTimerSeconds = 0
        restEndsAt = nil
        
        // Sync to draft for persistence
        draft.restEndDate = nil
        draft.restTotalSeconds = nil
        persistDraft(acknowledging: actionID)
    }
}
