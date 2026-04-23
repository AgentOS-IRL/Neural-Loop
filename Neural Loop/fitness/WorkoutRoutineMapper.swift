import Foundation

struct WorkoutRoutineMapper {
    static func mapToSessionState(
        routine: Routine,
        routineExercises: [RoutineExercise],
        allExercises: [Exercise],
        allEquipment: [Equipment]
    ) -> WorkoutSessionState {
        // 1. Prepare WorkoutSession Draft
        let session = WorkoutSession(
            id: nil,
            date: Date(),
            start_time: ISO8601DateFormatter().string(from: Date()),
            end_time: nil,
            session_type: routine.name,
            notes: routine.notes
        )

        // 2. Sort routine exercises by order_index
        let sortedRoutineExercises = routineExercises.sorted(by: { $0.order_index < $1.order_index })

        // 3. Transform to WorkoutExerciseCardState
        let exerciseStates = sortedRoutineExercises.compactMap { re -> WorkoutExerciseCardState? in
            guard let exercise = allExercises.first(where: { $0.id == re.exercise_id }) else {
                return nil
            }

            let equipment = allEquipment.first(where: { $0.id == exercise.equipment_id })
            
            let libraryItem = ExerciseLibraryItem(
                id: exercise.id ?? 0,
                name: exercise.name,
                type: exercise.type,
                equipmentID: exercise.equipment_id,
                equipmentName: equipment?.name ?? "No Equipment"
            )

            let targetSets = max(1, re.target_sets ?? 1)
            
            // For duration-based exercises, repsText might be empty or formatted differently
            // but the plan says "Carry over metadata: target_sets, target_reps, rest_seconds, duration"
            // and "Distinguish between rep-based and duration (cardio) exercises"
            
            let weightText = ""
            let repsText = re.target_reps.map { String($0) } ?? ""

            let setDrafts = (1...targetSets).map { setNumber in
                WorkoutSetDraft(
                    setNumber: setNumber,
                    weightText: weightText,
                    repsText: repsText
                )
            }

            return WorkoutExerciseCardState(
                id: re.id ?? 0,
                exercise: libraryItem,
                sets: setDrafts,
                targetSets: re.target_sets,
                targetReps: re.target_reps,
                restSeconds: re.rest_seconds,
                targetDuration: re.duration
            )
        }

        return WorkoutSessionState(session: session, exercises: exerciseStates)
    }
}
