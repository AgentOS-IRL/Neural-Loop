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
            guard exerciseState.exercise.isRepBased else { continue }
            
            do {
                let exerciseId = exerciseState.exercise.id
                let history = try await db.fetchWorkoutSets(exerciseId: exerciseId)
                
                // Group by session and find the latest one (highest ID as proxy for date if dates not available)
                let sessions = Dictionary(grouping: history, by: { $0.workout_session_id })
                guard let latestSessionId = sessions.keys.max() else { continue }
                let latestSets = sessions[latestSessionId]?.sorted(by: { $0.set_number < $1.set_number }) ?? []
                
                guard !latestSets.isEmpty else { continue }
                
                // Update sets in this exercise
                for j in 0..<updatedExercises[i].sets.count {
                    // Match by index, fallback to the last set if current session has more sets than history
                    let historicalSet = j < latestSets.count ? latestSets[j] : latestSets.last!
                    
                    if let weight = historicalSet.weight {
                        updatedExercises[i].sets[j].weightText = NumericFormatter.format(weight)
                    }
                    updatedExercises[i].sets[j].repsText = "\(historicalSet.reps)"
                }
                
                // Generate historical hint based on the best set of the latest session
                if let bestSet = latestSets.max(by: { 
                    let v1 = ($0.weight ?? 0) * Decimal($0.reps)
                    let v2 = ($1.weight ?? 0) * Decimal($1.reps)
                    return v1 < v2
                }) {
                    let weightStr = bestSet.weight.map { NumericFormatter.format($0) } ?? "0"
                    updatedExercises[i].historicalHint = "Last: \(weightStr)kg x \(bestSet.reps)"
                }
                
            } catch {
                // Gracefully ignore errors as per plan to allow workout to start regardless of history fetch success
                print("Error fetching history for exercise \(exerciseState.exercise.name): \(error)")
            }
        }

        return updatedExercises
    }
}
