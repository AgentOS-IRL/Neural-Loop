import Combine
import Foundation
import SwiftUI

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    @Published var session: WorkoutSession
    @Published var exerciseStates: [WorkoutExerciseCardState]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db: WorkoutDataManaging
    
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
                start_time: session.start_time,
                end_time: ISO8601DateFormatter().string(from: Date()),
                session_type: session.session_type,
                notes: session.notes
            )
            let savedSession = try await db.createWorkoutSession(sessionRequest)
            
            // 2. Create sets
            for exerciseState in exerciseStates {
                for draft in exerciseState.sets {
                    // Only save sets that have reps
                    guard let reps = Int(draft.repsText), reps > 0 else { continue }
                    
                    let setRequest = CreateWorkoutSetRequest(
                        workout_session_id: savedSession.id ?? 0,
                        exercise_id: exerciseState.exercise.id,
                        set_number: draft.setNumber,
                        reps: reps,
                        weight: Decimal(string: draft.weightText),
                        superset_group_id: nil
                    )
                    _ = try await db.createWorkoutSet(setRequest)
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
        exerciseStates[index].sets.append(WorkoutSetDraft(setNumber: nextSetNumber))
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
}
