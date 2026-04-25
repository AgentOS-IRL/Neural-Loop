import Combine
import Foundation
import SwiftUI

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    @Published var draft: ActiveWorkoutDraft
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var restTimerSeconds: Int = 0
    @Published var isTimerRunning: Bool = false
    
    private let draftKey = "active_workout_draft"
    let db: WorkoutDataManaging
    private var timerCancellable: AnyCancellable?
    private var saveCancellable: AnyCancellable?
    
    init(
        session: WorkoutSession,
        exerciseStates: [WorkoutExerciseCardState],
        db: WorkoutDataManaging
    ) {
        self.draft = ActiveWorkoutDraft(session: session, exercises: exerciseStates)
        self.db = db
        setupDraftPersistence()
    }
    
    private func setupDraftPersistence() {
        saveCancellable = $draft
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] draft in
                self?.persistDraft(draft)
            }
    }

    private func persistDraft(_ draft: ActiveWorkoutDraft) {
        if let encoded = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(encoded, forKey: draftKey)
        }
    }

    func clearDraft() {
        saveCancellable?.cancel()
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    func finishWorkout() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Create session
            let sessionRequest = CreateWorkoutSessionRequest(
                date: draft.session.date,
                start_time: WorkoutTimeCoding.normalize(draft.session.start_time),
                end_time: WorkoutTimeCoding.string(from: Date()),
                session_type: draft.session.session_type,
                notes: draft.session.notes
            )
            let savedSession = try await db.createWorkoutSession(sessionRequest)
            
            // 2. Create sets or cardio logs
            for exerciseState in draft.exercises {
                for setDraft in exerciseState.sets {
                    if exerciseState.exercise.isRepBased {
                        // Only save sets that have reps
                        guard let reps = Int(setDraft.repsText), reps > 0 else { continue }
                        
                        let setRequest = CreateWorkoutSetRequest(
                            workout_session_id: savedSession.id ?? 0,
                            exercise_id: exerciseState.exercise.id,
                            set_number: setDraft.setNumber,
                            reps: reps,
                            weight: NumericFormatter.parse(setDraft.weightText),
                            superset_group_id: exerciseState.supersetGroupID
                        )
                        _ = try await db.createWorkoutSet(setRequest)
                    } else if exerciseState.exercise.isDurationBased {
                        // Only save logs that have duration, distance or calories
                        let duration = NumericFormatter.parse(setDraft.durationText) ?? 0
                        let distanceKM = NumericFormatter.parse(setDraft.distanceText)
                        let calories = NumericFormatter.parse(setDraft.caloriesText)

                        guard duration > 0 || (distanceKM ?? 0) > 0 || (calories ?? 0) > 0 else { continue }

                        let cardioRequest = CreateCardioLogRequest(
                            workout_session_id: savedSession.id ?? 0,
                            exercise_id: exerciseState.exercise.id,
                            distance_meters: distanceKM.map { $0 * 1000 },
                            duration_minutes: duration > 0 ? duration : nil,
                            calories: nil // Guarded: calories // FIXME: Restore once cardio_log.calories column is verified in production
                        )
                        _ = try await db.createCardioLog(cardioRequest)
                    }
                }
            }
            clearDraft()
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
    }
    
    func updateWeight(for exerciseID: Int64, setID: UUID, weightText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].weightText = weightText
    }
    
    func updateReps(for exerciseID: Int64, setID: UUID, repsText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].repsText = repsText
    }

    func updateDuration(for exerciseID: Int64, setID: UUID, durationText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].durationText = durationText
    }

    func updateDistance(for exerciseID: Int64, setID: UUID, distanceText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].distanceText = distanceText
    }

    func updateCalories(for exerciseID: Int64, setID: UUID, caloriesText: String) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draft.exercises[exerciseIndex].sets[setIndex].caloriesText = caloriesText
    }

    func toggleSetCompletion(exerciseID: Int64, setID: UUID) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        
        draft.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
        
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
