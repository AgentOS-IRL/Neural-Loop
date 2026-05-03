import Foundation

struct WorkoutSessionLoader {
    private let db: WorkoutDataManaging

    init(db: WorkoutDataManaging) {
        self.db = db
    }

    func prefillHistoricalWeights(for exercises: [WorkoutExerciseCardState]) async -> [WorkoutExerciseCardState] {
        let repBasedExerciseIds = exercises.filter { $0.exercise.isRepBased }.map { $0.exercise.id }
        guard !repBasedExerciseIds.isEmpty else { return exercises }

        var updatedExercises = exercises

        do {
            let latestSets = try await db.fetchLatestExerciseHistory(exerciseIds: repBasedExerciseIds)
            let setsByExercise = Dictionary(grouping: latestSets, by: { $0.exercise_id })

            for i in 0..<updatedExercises.count {
                let exerciseId = updatedExercises[i].exercise.id
                guard let history = setsByExercise[exerciseId], !history.isEmpty else { continue }
                
                let latestSetsForExercise = history.sorted(by: { $0.set_number < $1.set_number })

                // Update sets in this exercise
                for j in 0..<updatedExercises[i].sets.count {
                    // Match by index, fallback to the last set if current session has more sets than history
                    let historicalSet = j < latestSetsForExercise.count ? latestSetsForExercise[j] : latestSetsForExercise.last!
                    
                    if let weight = historicalSet.weight {
                        updatedExercises[i].sets[j].weightText = NumericFormatter.format(weight)
                    }
                    updatedExercises[i].sets[j].repsText = "\(historicalSet.reps)"
                }
                
                // Generate historical hint based on the best set of the latest session
                if let bestSet = latestSetsForExercise.max(by: { 
                    let v1 = ($0.weight ?? 0) * Decimal($0.reps)
                    let v2 = ($1.weight ?? 0) * Decimal($1.reps)
                    return v1 < v2
                }) {
                    if let weight = bestSet.weight {
                        let weightStr = NumericFormatter.format(weight)
                        updatedExercises[i].historicalHint = "Last: \(weightStr)kg x \(bestSet.reps)"
                    } else {
                        updatedExercises[i].historicalHint = "Last: \(bestSet.reps) reps"
                    }
                }
            }
        } catch {
            // Gracefully ignore errors as per plan to allow workout to start regardless of history fetch success
            print("Error fetching combined history: \(error)")
        }

        return updatedExercises
    }
}
