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

        // 2. Map to WorkoutSessionState using the mapper
        let sessionState = WorkoutRoutineMapper.mapToSessionState(
            routine: routine,
            routineExercises: routineExercises,
            allExercises: allExercises,
            allEquipment: allEquipment
        )

        return (sessionState.session, sessionState.exercises)
    }
}
