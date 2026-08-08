import Combine
import Foundation

struct FitnessMuscleVolume: Identifiable, Equatable {
    let name: String
    var volume: Double

    var id: String { name }
}

struct FitnessProgressionPoint: Identifiable, Equatable {
    let date: Date
    var volume: Double

    var id: Date { date }
}

struct FitnessAnalysisSummary: Equatable {
    static let defaultMuscleVolumes: [FitnessMuscleVolume] = [
        FitnessMuscleVolume(name: "Chest", volume: 0),
        FitnessMuscleVolume(name: "Back", volume: 0),
        FitnessMuscleVolume(name: "Legs", volume: 0),
        FitnessMuscleVolume(name: "Core", volume: 0),
        FitnessMuscleVolume(name: "Shoulders", volume: 0),
        FitnessMuscleVolume(name: "Arms", volume: 0)
    ]

    static let empty = FitnessAnalysisSummary(
        totalVolume: 0,
        muscleVolumes: defaultMuscleVolumes,
        muscleFrequencies: defaultMuscleVolumes,
        progressionPoints: []
    )

    var totalVolume: Double
    var muscleVolumes: [FitnessMuscleVolume]
    var muscleFrequencies: [FitnessMuscleVolume]
    var progressionPoints: [FitnessProgressionPoint]

    var hasStrengthData: Bool {
        totalVolume > 0 ||
            muscleFrequencies.contains { $0.volume > 0 } ||
            progressionPoints.contains { $0.volume > 0 }
    }
}

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplateSummary] = []
    @Published private(set) var sessions: [WorkoutSessionSummary] = []
    @Published private(set) var activeDraftSummary: WorkoutDraftSummary?
    @Published private(set) var analysisSummary: FitnessAnalysisSummary = .empty
    @Published private(set) var isLoading = false
    @Published var activeViewModel: ActiveWorkoutViewModel?
    @Published var errorMessage: String?

    private let dataManager: any FitnessHomeReading
    let launchCoordinator: WorkoutSessionLaunching
    private let runtime: any WorkoutSessionRuntimeCoordinating
    private let activeViewModelFactory: (ActiveWorkoutDraft) -> ActiveWorkoutViewModel
    var persistenceManager: WorkoutDraftPersistenceManager { runtime.persistenceManager }
    private var hasLoaded = false
    private var stateRevision: UInt64 = 0

    init(
        dataManager: (any FitnessHomeReading & WorkoutRoutineReading & WorkoutCatalogReading & WorkoutLaunchHistoryReading & WorkoutFinalizationPersisting & ExerciseProgressionReading)? = nil,
        launchCoordinator: WorkoutSessionLaunching? = nil,
        persistenceManager: WorkoutDraftPersistenceManager? = nil,
        connectivityManager: (any WorkoutConnectivityProviding)? = nil
    ) {
        let dm = dataManager ?? DBManager.newInstance()
        let pm = persistenceManager ?? WorkoutDraftPersistenceManager()
        let cm = connectivityManager ?? ConnectivityManager.shared
        let finalizer = WorkoutSessionFinalizer(db: dm, persistenceManager: pm)
        let runtime = WorkoutSessionRuntimeCoordinator(
            persistenceManager: pm,
            connectivityProvider: cm,
            finalizer: finalizer
        )
        self.dataManager = dm
        self.runtime = runtime
        self.activeViewModelFactory = { draft in
            ActiveWorkoutViewModel(
                draft: draft,
                db: dm,
                runtime: runtime
            )
        }
        self.launchCoordinator = launchCoordinator ?? WorkoutSessionLaunchCoordinator(
            db: dm,
            persistenceManager: pm,
            connectivityProvider: cm,
            runtime: runtime
        )
        
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
                do {
                    let outcome = try await runtime.handleBackground(action: action)
                    if case .finalized = outcome {
                        await reload()
                    }
                } catch {
                    print("Workout action handling failed: \(error)")
                    errorMessage = error.localizedDescription
                }
            }

            activeDraftSummary = loadActiveDraftSummary()
        }
    }

    func startWorkout(routineID: Int64) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let draft = try await launchCoordinator.launchSession(for: routineID)
            activeDraftSummary = draft.summary
            activeViewModel = makeActiveViewModel(draft: draft)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func clearActiveDraft() {
        activeViewModel = nil
    }

    func deleteActiveDraft(routineID: Int64) async -> Bool {
        let draft: ActiveWorkoutDraft?
        if let persistedDraft = persistenceManager.load(routineID: routineID) {
            draft = persistedDraft
        } else if activeViewModel?.draft.routineID == routineID {
            draft = activeViewModel?.draft
        } else {
            draft = nil
        }

        guard let draft else {
            if activeDraftSummary?.routineID == routineID {
                activeDraftSummary = nil
            }
            if activeViewModel?.draft.routineID == routineID {
                activeViewModel = nil
            }
            return false
        }

        let wasMounted = activeViewModel?.draft.routineID == routineID

        runtime.discard(draft, reason: .cancelledOnPhone)

        if wasMounted {
            activeViewModel = nil
        }

        if activeDraftSummary?.routineID == routineID {
            activeDraftSummary = nil
        }

        return true
    }

    /// Attempts to resume an active workout session from the persisted draft.
    /// Called when the user taps the Live Activity / Dynamic Island to return
    /// to an in-progress workout.
    func resumeActiveWorkout() {
        // Already showing an active workout
        guard activeViewModel == nil else { return }

        guard let pointer = persistenceManager.loadActiveSessionPointer(),
              let routineID = pointer.routineID,
              let draft = persistenceManager.load(routineID: routineID) else {
            activeDraftSummary = loadActiveDraftSummary()
            return
        }

        activeDraftSummary = draft.summary
        activeViewModel = makeActiveViewModel(draft: draft)
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
            let bundle = try await dataManager.fetchFitnessHomeBundle(daysBack: 29)

            let analysis = Self.makeAnalysisSummary(from: bundle.analysis)

            guard revision == stateRevision else {
                return
            }

            templates = bundle.routines
            sessions = bundle.sessions.map { session in
                WorkoutSessionSummary(
                    id: session.id ?? 0,
                    date: session.date,
                    title: session.session_type,
                    notes: session.notes,
                    startTime: session.start_time,
                    endTime: session.end_time
                )
            }
            analysisSummary = analysis
            activeDraftSummary = loadActiveDraftSummary()
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadActiveDraftSummary() -> WorkoutDraftSummary? {
        guard let pointer = persistenceManager.loadActiveSessionPointer(),
              let routineID = pointer.routineID,
              let draft = persistenceManager.load(routineID: routineID) else {
            return nil
        }

        return draft.summary
    }

    private func makeActiveViewModel(draft: ActiveWorkoutDraft) -> ActiveWorkoutViewModel {
        let viewModel = activeViewModelFactory(draft)
        viewModel.onFinish = { [weak self] in
            self?.activeViewModel = nil
            Task { [weak self] in
                await self?.reload()
            }
        }
        return viewModel
    }

    private static func makeAnalysisSummary(
        from response: FitnessAnalysisSummaryResponse
    ) -> FitnessAnalysisSummary {
        var totalVolume = 0.0
        var muscleVolumeByBucket = Dictionary(
            uniqueKeysWithValues: FitnessAnalysisSummary.defaultMuscleVolumes.map { ($0.name, 0.0) }
        )
        var muscleFrequencyByBucket = Dictionary(
            uniqueKeysWithValues: FitnessAnalysisSummary.defaultMuscleVolumes.map { ($0.name, 0.0) }
        )

        for ev in response.exercise_volumes {
            totalVolume += ev.volume
            let buckets = bucketNames(for: ev.primary_muscles)
            guard !buckets.isEmpty else { continue }
            
            let splitVolume = ev.volume / Double(buckets.count)
            for bucket in buckets {
                muscleVolumeByBucket[bucket, default: 0] += splitVolume
                muscleFrequencyByBucket[bucket, default: 0] += 1
            }
        }

        let muscleVolumes = FitnessAnalysisSummary.defaultMuscleVolumes.map { muscle in
            FitnessMuscleVolume(
                name: muscle.name,
                volume: muscleVolumeByBucket[muscle.name] ?? 0
            )
        }
        let muscleFrequencies = FitnessAnalysisSummary.defaultMuscleVolumes.map { muscle in
            FitnessMuscleVolume(
                name: muscle.name,
                volume: muscleFrequencyByBucket[muscle.name] ?? 0
            )
        }

        let progressionPoints = response.daily_volumes.compactMap { dv -> FitnessProgressionPoint? in
            guard let date = WorkoutDateCoding.date(from: dv.date) else { return nil }
            return FitnessProgressionPoint(date: date, volume: dv.volume)
        }
        .sorted { $0.date < $1.date }

        return FitnessAnalysisSummary(
            totalVolume: totalVolume,
            muscleVolumes: muscleVolumes,
            muscleFrequencies: muscleFrequencies,
            progressionPoints: progressionPoints
        )
    }

    private static func bucketNames(for muscleNames: [String]) -> [String] {
        var buckets: Set<String> = []

        for muscleName in muscleNames {
            let normalized = muscleName.lowercased()

            if normalized.contains("chest") || normalized.contains("pectoral") {
                buckets.insert("Chest")
            }

            if normalized.contains("back") ||
                normalized.contains("lat") ||
                normalized.contains("trap") ||
                normalized.contains("rhomboid") {
                buckets.insert("Back")
            }

            if normalized.contains("quad") ||
                normalized.contains("hamstring") ||
                normalized.contains("glute") ||
                normalized.contains("calf") ||
                normalized.contains("leg") ||
                normalized.contains("adductor") ||
                normalized.contains("abductor") {
                buckets.insert("Legs")
            }

            if normalized.contains("core") ||
                normalized.contains("ab") ||
                normalized.contains("oblique") {
                buckets.insert("Core")
            }

            if normalized.contains("shoulder") || normalized.contains("deltoid") {
                buckets.insert("Shoulders")
            }

            if normalized.contains("bicep") ||
                normalized.contains("tricep") ||
                normalized.contains("forearm") ||
                normalized.contains("arm") {
                buckets.insert("Arms")
            }
        }

        return FitnessAnalysisSummary.defaultMuscleVolumes
            .map(\.name)
            .filter { buckets.contains($0) }
    }
}
