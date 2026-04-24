import Combine
import Foundation
import SwiftUI

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    @Published var session: WorkoutSession
    @Published var exerciseStates: [WorkoutExerciseCardState]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var restTimerSeconds: Int = 0
    @Published var isTimerRunning: Bool = false
    
    private let db: WorkoutDataManaging
    private var timerCancellable: AnyCancellable?
    
    init(
        session: WorkoutSession,
        exerciseStates: [WorkoutExerciseCardState],
        db: WorkoutDataManaging
    ) {
        self.session = session
        self.exerciseStates = exerciseStates
        self.db = db
    }
    
    func finishWorkout() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Create session
            let sessionRequest = CreateWorkoutSessionRequest(
                date: session.date,
                start_time: WorkoutTimeCoding.normalize(session.start_time),
                end_time: WorkoutTimeCoding.string(from: Date()),
                session_type: session.session_type,
                notes: session.notes
            )
            let savedSession = try await db.createWorkoutSession(sessionRequest)
            
            // 2. Create sets or cardio logs
            for exerciseState in exerciseStates {
                for draft in exerciseState.sets {
                    if exerciseState.exercise.isRepBased {
                        // Only save sets that have reps
                        guard let reps = Int(draft.repsText), reps > 0 else { continue }
                        
                        let setRequest = CreateWorkoutSetRequest(
                            workout_session_id: savedSession.id ?? 0,
                            exercise_id: exerciseState.exercise.id,
                            set_number: draft.setNumber,
                            reps: reps,
                            weight: NumericFormatter.parse(draft.weightText),
                            superset_group_id: exerciseState.supersetGroupID
                        )
                        _ = try await db.createWorkoutSet(setRequest)
                    } else if exerciseState.exercise.isDurationBased {
                        // Only save logs that have duration, distance or calories
                        let duration = NumericFormatter.parse(draft.durationText) ?? 0
                        let distanceKM = NumericFormatter.parse(draft.distanceText)
                        let calories = NumericFormatter.parse(draft.caloriesText)

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
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addSet(to exerciseID: Int64) {
        guard let index = exerciseStates.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextSetNumber = (exerciseStates[index].sets.map(\.setNumber).max() ?? 0) + 1
        let lastReps = exerciseStates[index].sets.last?.repsText ?? ""
        let lastWeight = exerciseStates[index].sets.last?.weightText ?? ""
        let lastDuration = exerciseStates[index].sets.last?.durationText ?? ""
        let lastDistance = exerciseStates[index].sets.last?.distanceText ?? ""
        let lastCalories = exerciseStates[index].sets.last?.caloriesText ?? ""
        
        exerciseStates[index].sets.append(WorkoutSetDraft(
            setNumber: nextSetNumber,
            weightText: lastWeight,
            repsText: lastReps,
            durationText: lastDuration,
            distanceText: lastDistance,
            caloriesText: lastCalories
        ))
    }
    
    func updateWeight(for exerciseID: Int64, setID: UUID, weightText: String) {
        guard let exerciseIndex = exerciseStates.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exerciseStates[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        exerciseStates[exerciseIndex].sets[setIndex].weightText = weightText
    }
    
    func updateReps(for exerciseID: Int64, setID: UUID, repsText: String) {
        guard let exerciseIndex = exerciseStates.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exerciseStates[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        exerciseStates[exerciseIndex].sets[setIndex].repsText = repsText
    }

    func updateDuration(for exerciseID: Int64, setID: UUID, durationText: String) {
        guard let exerciseIndex = exerciseStates.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exerciseStates[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        exerciseStates[exerciseIndex].sets[setIndex].durationText = durationText
    }

    func updateDistance(for exerciseID: Int64, setID: UUID, distanceText: String) {
        guard let exerciseIndex = exerciseStates.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exerciseStates[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        exerciseStates[exerciseIndex].sets[setIndex].distanceText = distanceText
    }

    func updateCalories(for exerciseID: Int64, setID: UUID, caloriesText: String) {
        guard let exerciseIndex = exerciseStates.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exerciseStates[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        exerciseStates[exerciseIndex].sets[setIndex].caloriesText = caloriesText
    }

    func toggleSetCompletion(exerciseID: Int64, setID: UUID) {
        guard let exerciseIndex = exerciseStates.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exerciseStates[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        
        exerciseStates[exerciseIndex].sets[setIndex].isCompleted.toggle()
        
        if exerciseStates[exerciseIndex].sets[setIndex].isCompleted {
            if let restSeconds = exerciseStates[exerciseIndex].restSeconds, restSeconds > 0 {
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
