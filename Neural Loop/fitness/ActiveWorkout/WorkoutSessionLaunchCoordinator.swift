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

@MainActor
protocol WorkoutSessionLaunching {
    func launchSession(for routineID: Int64) async throws -> ActiveWorkoutDraft
}

@MainActor
final class WorkoutSessionLaunchCoordinator: WorkoutSessionLaunching {
    private let db: any WorkoutRoutineReading & WorkoutCatalogReading & WorkoutLaunchHistoryReading
    private let runtime: any WorkoutSessionRuntimeCoordinating
    private var isLaunching = false

    init(
        db: any WorkoutRoutineReading & WorkoutCatalogReading & WorkoutLaunchHistoryReading,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager(),
        connectivityProvider: WorkoutConnectivityProviding = ConnectivityManager.shared,
        runtime: (any WorkoutSessionRuntimeCoordinating)? = nil
    ) {
        self.db = db
        self.runtime = runtime ?? WorkoutSessionRuntimeCoordinator(
            persistenceManager: persistenceManager,
            connectivityProvider: connectivityProvider
        )
    }

    func launchSession(for routineID: Int64) async throws -> ActiveWorkoutDraft {
        guard !isLaunching else {
            throw WorkoutLaunchError.launchInProgress
        }

        isLaunching = true
        defer { isLaunching = false }

        if let draft = runtime.persistenceManager.load(routineID: routineID) {
            runtime.start(draft)
            return draft
        }

        // 1. Fetch routine and exercises
        async let routineTask = db.fetchRoutine(by: routineID)
        async let routineExercisesTask = db.fetchRoutineExercises(routineId: routineID)
        async let allExercisesTask = db.fetchAllExercisesWithMuscles()
        async let allEquipmentTask = db.fetchAllEquipment()

        guard let routine = try await routineTask else {
            throw WorkoutLaunchError.routineNotFound
        }

        let routineExercises = try await routineExercisesTask
        let allExercises = try await allExercisesTask
        let allEquipment = try await allEquipmentTask

        // 2. Map to ActiveWorkoutDraft using the mapper
        var draft = WorkoutRoutineMapper.mapToSessionState(
            routine: routine,
            routineExercises: routineExercises,
            allExercises: allExercises,
            allEquipment: allEquipment
        )

        // 3. Load history and explicit suggestions without changing today's entries.
        let loader = WorkoutSessionLoader(db: db)
        draft.exercises = await loader.loadHistory(for: draft.exercises, routineID: routineID)

        // 4. Immediate Save
        runtime.start(draft)

        return draft
    }
}
