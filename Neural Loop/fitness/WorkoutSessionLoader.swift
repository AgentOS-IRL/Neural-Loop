import Foundation

struct WorkoutSessionLoader {
    private let db: WorkoutDataManaging

    init(db: WorkoutDataManaging) {
        self.db = db
    }

    func prefillHistoricalWeights(for exercises: [WorkoutExerciseCardState]) async -> [WorkoutExerciseCardState] {
        var updatedExercises = exercises

        for i in 0..<updatedExercises.count {
            let exerciseState = updatedExercises[i]
            
            // Only prefill for rep-based exercises
            guard exerciseState.exercise.type == .repBased else { continue }
            
            do {
                let exerciseId = exerciseState.exercise.id
                let history = try await db.fetchWorkoutSets(exerciseId: exerciseId)
                
                // Extract weights and find the maximum
                let weights = history.compactMap { $0.weight }
                if let maxWeight = weights.max() {
                    let weightString = WeightFormatter.format(maxWeight)
                    
                    // Update all sets in this exercise
                    for j in 0..<updatedExercises[i].sets.count {
                        updatedExercises[i].sets[j].weightText = weightString
                    }
                }
            } catch {
                // Gracefully ignore errors as per plan to allow workout to start regardless of history fetch success
                print("Error fetching history for exercise \(exerciseState.exercise.name): \(error)")
            }
        }

        return updatedExercises
    }
}
