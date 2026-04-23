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
    
    func finishWorkout() {
        // Implementation for finishing workout can be added later
        // For now, we just need a placeholder that can be used to dismiss the view
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
