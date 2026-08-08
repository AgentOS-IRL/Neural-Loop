import Foundation

struct WorkoutRoutineMapper {
    static func mapToSessionState(
        routine: Routine,
        routineExercises: [RoutineExercise],
        allExercises: [ExerciseWithMuscles],
        allEquipment: [Equipment]
    ) -> ActiveWorkoutDraft {
        let now = Date()

        // 1. Prepare WorkoutSession Draft
        let session = WorkoutSession(
            id: nil,
            date: now,
            start_time: WorkoutTimeCoding.string(from: now),
            end_time: nil,
            session_type: routine.name,
            notes: routine.notes,
            routine_id: routine.id
        )

        // 2. Sort routine exercises by order_index
        let sortedRoutineExercises = routineExercises.sorted(by: { $0.order_index < $1.order_index })

        // 3. Transform to WorkoutExerciseCardState
        let exerciseStates = sortedRoutineExercises.compactMap { re -> WorkoutExerciseCardState? in
            guard let exercise = allExercises.first(where: { $0.id == re.exercise_id }) else {
                return nil
            }

            let equipment = allEquipment.first(where: { $0.id == exercise.equipment_id })
            
            let muscles = exercise.exercise_muscles
                .map { MuscleMetadata(muscleID: $0.muscle.id ?? 0, muscleName: $0.muscle.name, isPrimary: $0.is_primary) }
                .sorted { lhs, rhs in
                    if lhs.isPrimary != rhs.isPrimary {
                        return lhs.isPrimary // Primaries first
                    }
                    return lhs.muscleName.localizedCaseInsensitiveCompare(rhs.muscleName) == .orderedAscending
                }

            let libraryItem = ExerciseLibraryItem(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                equipmentID: exercise.equipment_id,
                equipmentName: equipment?.name ?? "No Equipment",
                muscles: muscles
            )

            let targetSets = max(1, re.target_sets ?? 1)
            let warmupSets = exercise.isRepBased ? max(0, re.warmup_sets) : 0

            let warmupDrafts = warmupSets == 0 ? [] : (1...warmupSets).map { setNumber in
                WorkoutSetDraft(
                    setNumber: setNumber,
                    setType: .warmup
                )
            }

            let workingDrafts = (1...targetSets).map { setNumber in
                WorkoutSetDraft(setNumber: setNumber, setType: .working)
            }

            let repRange: WorkoutRepRange?
            if exercise.isRepBased,
               let minimum = re.target_reps_min,
               let maximum = re.target_reps_max {
                repRange = WorkoutRepRange(minimum: minimum, maximum: maximum)
            } else {
                repRange = nil
            }

            return WorkoutExerciseCardState(
                id: re.id ?? 0,
                exercise: libraryItem,
                sets: warmupDrafts + workingDrafts,
                targetSets: re.target_sets,
                targetRepRange: repRange,
                warmupSets: re.warmup_sets,
                loadIncrementKg: re.load_increment_kg,
                restSeconds: re.rest_seconds,
                targetDuration: re.duration,
                supersetGroupID: re.superset_group_id
            )
        }

        return ActiveWorkoutDraft(
            routineID: routine.id ?? 0,
            session: session,
            exercises: exerciseStates,
            createdAt: now,
            updatedAt: now
        )
    }
}
