import Combine
import Foundation

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplateSummary] = []
    @Published private(set) var sessions: [WorkoutSessionSummary] = []
    @Published private(set) var isLoading = false
    @Published var activeDraft: ActiveWorkoutDraft?
    @Published var errorMessage: String?

    private let dataManager: FitnessTemplateDataManaging & WorkoutDataManaging
    let launchCoordinator: WorkoutSessionLaunching
    private let persistenceManager: WorkoutDraftPersistenceManager
    private var hasLoaded = false
    private var stateRevision: UInt64 = 0
    private var cancellables = Set<AnyCancellable>()

    init(
        dataManager: (any FitnessTemplateDataManaging & WorkoutDataManaging)? = nil,
        launchCoordinator: WorkoutSessionLaunching? = nil,
        persistenceManager: WorkoutDraftPersistenceManager? = nil
    ) {
        let dm = dataManager ?? DBManager.newInstance()
        let pm = persistenceManager ?? WorkoutDraftPersistenceManager()
        self.dataManager = dm
        self.persistenceManager = pm
        self.launchCoordinator = launchCoordinator ?? WorkoutSessionLaunchCoordinator(db: dm, persistenceManager: pm)
        setupDraftPersistence()
    }

    private func setupDraftPersistence() {
        $activeDraft
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] draft in
                if let draft = draft {
                    self?.persistenceManager.save(draft: draft)
                } else {
                    self?.persistenceManager.clear()
                }
            }
            .store(in: &cancellables)
    }

    func startWorkout(routineID: Int64) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            activeDraft = try await launchCoordinator.launchSession(for: routineID)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func clearActiveDraft() {
        persistenceManager.clear()
        activeDraft = nil
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

        checkPersistedDraft()
        await load()
    }

    private func checkPersistedDraft() {
        if let draft = persistenceManager.load() {
            self.activeDraft = draft
        }
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
