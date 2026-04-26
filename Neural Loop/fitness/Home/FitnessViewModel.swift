import Combine
import Foundation

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplateSummary] = []
    @Published private(set) var sessions: [WorkoutSessionSummary] = []
    @Published private(set) var isLoading = false
    @Published var activeViewModel: ActiveWorkoutViewModel?
    @Published var errorMessage: String?

    private let dataManager: FitnessTemplateDataManaging & WorkoutDataManaging
    let launchCoordinator: WorkoutSessionLaunching
    let persistenceManager: WorkoutDraftPersistenceManager
    private let connectivityProvider: WorkoutConnectivityProviding
    private let finalizer: WorkoutSessionFinalizing
    private var hasLoaded = false
    private var stateRevision: UInt64 = 0

    init(
        dataManager: (any FitnessTemplateDataManaging & WorkoutDataManaging)? = nil,
        launchCoordinator: WorkoutSessionLaunching? = nil,
        persistenceManager: WorkoutDraftPersistenceManager? = nil,
        connectivityManager: (any WorkoutConnectivityProviding)? = nil
    ) {
        let dm = dataManager ?? DBManager.newInstance()
        let pm = persistenceManager ?? WorkoutDraftPersistenceManager()
        let cm = connectivityManager ?? ConnectivityManager.shared
        self.dataManager = dm
        self.persistenceManager = pm
        self.connectivityProvider = cm
        self.launchCoordinator = launchCoordinator ?? WorkoutSessionLaunchCoordinator(db: dm, persistenceManager: pm, connectivityProvider: cm)
        self.finalizer = WorkoutSessionFinalizer(db: dm, persistenceManager: pm)
        
        if let connectivityManager = cm as? ConnectivityManager {
            connectivityManager.actionHandler = { [weak self] action in
                self?.handleWatchAction(action)
            }
        }
    }

    func handleWatchAction(_ action: WorkoutWatchAction) {
        Task { @MainActor in
            if let activeVM = activeViewModel,
               activeVM.draft.watchSessionPointer.id == action.payload.session.id {
                await activeVM.apply(watchAction: action)
            } else {
                // Fallback: handle actions when no active view model is mounted
                switch action.payload {
                case .requestSnapshot:
                    if let routineID = action.payload.session.routineID,
                       let draft = persistenceManager.load(routineID: routineID),
                       draft.watchSessionPointer.id == action.payload.session.id {
                        let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                    }
                case .finishWorkout:
                    if let routineID = action.payload.session.routineID,
                       let draft = persistenceManager.load(routineID: routineID),
                       draft.watchSessionPointer.id == action.payload.session.id {
                        try? await finalizer.finalize(draft: draft)
                        await reload()
                    }
                default:
                    _ = persistenceManager.apply(action: action)
                    // If we apply an action, we should ideally send back a snapshot with lastProcessedActionID
                    if let routineID = action.payload.session.routineID,
                       let draft = persistenceManager.load(routineID: routineID),
                       draft.watchSessionPointer.id == action.payload.session.id {
                        let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                    }
                }
            }
        }
    }

    func startWorkout(routineID: Int64) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let draft = try await launchCoordinator.launchSession(for: routineID)
            activeViewModel = ActiveWorkoutViewModel(
                draft: draft,
                db: dataManager,
                persistenceManager: persistenceManager,
                connectivityProvider: connectivityProvider,
                onFinish: { [weak self] in
                    self?.activeViewModel = nil
                    Task { [weak self] in
                        await self?.reload()
                    }
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func clearActiveDraft() {
        activeViewModel = nil
    }

    func deleteSession(id: Int64) async -> Bool {
        stateRevision &+= 1
        defer { stateRevision &+= 1 }
        errorMessage = nil

        do {
            try await dataManager.deleteWorkoutSession(id: id)
            sessions.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else {
            return
        }

        await load()
    }

    func reload() async {
        hasLoaded = false
        await load()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let revision = stateRevision

        do {
            async let routinesTask = dataManager.fetchAllRoutines()
            async let sessionsTask = dataManager.fetchWorkoutSessions()

            let (routines, workoutSessions) = try await (routinesTask, sessionsTask)

            let sortedRoutines = routines.compactMap { routine -> (id: Int64, routine: Routine)? in
                guard let id = routine.id else {
                    return nil
                }

                return (id: id, routine: routine)
            }
            .sorted { lhs, rhs in
                switch lhs.routine.name.localizedCaseInsensitiveCompare(rhs.routine.name) {
                case .orderedAscending:
                    return true
                case .orderedDescending:
                    return false
                case .orderedSame:
                    return lhs.id < rhs.id
                @unknown default:
                    return lhs.id < rhs.id
                }
            }

            var loadedTemplates: [WorkoutTemplateSummary] = []
            loadedTemplates.reserveCapacity(sortedRoutines.count)

            for entry in sortedRoutines {
                let routineExercises = try await dataManager.fetchRoutineExercises(routineId: entry.id)
                loadedTemplates.append(Self.makeSummary(for: entry.routine, routineExercises: routineExercises))
            }

            guard revision == stateRevision else {
                return
            }

            templates = loadedTemplates
            sessions = workoutSessions.map { session in
                WorkoutSessionSummary(
                    id: session.id ?? 0,
                    date: session.date,
                    title: session.session_type,
                    notes: session.notes
                )
            }
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeSummary(
        for routine: Routine,
        routineExercises: [RoutineExercise]
    ) -> WorkoutTemplateSummary {
        let exerciseCount = routineExercises.count
        let setCount = routineExercises.reduce(0) { partialResult, routineExercise in
            partialResult + (routineExercise.target_sets ?? 1)
        }

        return WorkoutTemplateSummary(
            id: routine.id ?? 0,
            title: routine.name,
            exerciseCount: exerciseCount,
            setCount: setCount
        )
    }
}
