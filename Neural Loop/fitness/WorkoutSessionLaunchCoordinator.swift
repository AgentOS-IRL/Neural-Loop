import Foundation

enum WorkoutLaunchError: LocalizedError {
    case routineNotFound
    case launchInProgress

    var errorDescription: String? {
        switch self {
        case .routineNotFound:
            return "The selected routine could not be found."
        case .launchInProgress:
            return "A workout session is already being started."
        }
    }
}

protocol WorkoutSessionLaunching {
    func launchSession(for routineID: Int64) async throws -> (WorkoutSession, [WorkoutExerciseCardState])
}

actor WorkoutSessionLaunchCoordinator: WorkoutSessionLaunching {
    private let db: WorkoutTemplateReadingDataManaging & WorkoutDataManaging
    private var isLaunching = false

    init(db: WorkoutTemplateReadingDataManaging & WorkoutDataManaging) {
        self.db = db
    }

    func launchSession(for routineID: Int64) async throws -> (WorkoutSession, [WorkoutExerciseCardState]) {
        guard !isLaunching else {
            throw WorkoutLaunchError.launchInProgress
        }

        isLaunching = true
        defer { isLaunching = false }

        // 1. Fetch routine and exercises
        guard let routine = try await db.fetchRoutine(by: routineID) else {
            throw WorkoutLaunchError.routineNotFound
        }

        let routineExercises = try await db.fetchRoutineExercises(routineId: routineID)
        let allExercises = try await db.fetchAllExercises()
        let allEquipment = try await db.fetchAllEquipment()

        // 2. Prepare WorkoutSession Draft
        let session = WorkoutSession(
            id: nil,
            date: Date(),
            start_time: ISO8601DateFormatter().string(from: Date()),
            end_time: nil,
            session_type: routine.name,
            notes: routine.notes
        )

        // 3. Transform to WorkoutExerciseCardState
        let exerciseStates = routineExercises.compactMap { re -> WorkoutExerciseCardState? in
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
                sets: setDrafts
            )
        }

        return (session, exerciseStates)
    }
}
