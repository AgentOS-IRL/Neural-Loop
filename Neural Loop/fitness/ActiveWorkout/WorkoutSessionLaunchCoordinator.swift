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
    func launchSession(for routineID: Int64) async throws -> ActiveWorkoutDraft
}

actor WorkoutSessionLaunchCoordinator: WorkoutSessionLaunching {
    private let db: WorkoutTemplateReadingDataManaging & WorkoutDataManaging
    private let persistenceManager: WorkoutDraftPersistenceManager
    private let connectivityProvider: WorkoutConnectivityProviding
    private var isLaunching = false

    init(
        db: WorkoutTemplateReadingDataManaging & WorkoutDataManaging,
        persistenceManager: WorkoutDraftPersistenceManager = WorkoutDraftPersistenceManager(),
        connectivityProvider: WorkoutConnectivityProviding = ConnectivityManager.shared
    ) {
        self.db = db
        self.persistenceManager = persistenceManager
        self.connectivityProvider = connectivityProvider
    }

    func launchSession(for routineID: Int64) async throws -> ActiveWorkoutDraft {
        guard !isLaunching else {
            throw WorkoutLaunchError.launchInProgress
        }

        isLaunching = true
        defer { isLaunching = false }

        if let draft = persistenceManager.load(routineID: routineID) {
            persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)
            let snapshot = draft.watchSnapshot()
            connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
            // Start Live Activity for resumed session
            await MainActor.run {
                WorkoutLiveActivityManager.shared.startActivity(snapshot: snapshot)
            }
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

        // 3. Prefill historical weights
        let loader = WorkoutSessionLoader(db: db)
        let prefilledExercises = await loader.prefillHistoricalWeights(for: draft.exercises)
        draft.exercises = prefilledExercises

        // 4. Immediate Save
        persistenceManager.save(draft: draft)
        persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)
        
        // 5. Sync to Watch (side effect)
        let snapshot = draft.watchSnapshot()
        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)

        // 6. Start Live Activity for new session
        await MainActor.run {
            WorkoutLiveActivityManager.shared.startActivity(snapshot: snapshot)
        }

        return draft
    }
}
