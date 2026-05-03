import Combine
import ActivityKit
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
        progressionPoints: []
    )

    var totalVolume: Double
    var muscleVolumes: [FitnessMuscleVolume]
    var progressionPoints: [FitnessProgressionPoint]

    var hasStrengthData: Bool {
        totalVolume > 0 || progressionPoints.contains { $0.volume > 0 }
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
                       var draft = persistenceManager.load(routineID: routineID),
                       draft.watchSessionPointer.id == action.payload.session.id {
                        draft.markProcessed(action: action)
                        persistenceManager.save(draft: draft)
                        let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                    }
                case .finishWorkout:
                    if let routineID = action.payload.session.routineID,
                       var draft = persistenceManager.load(routineID: routineID),
                       draft.watchSessionPointer.id == action.payload.session.id {
                        do {
                            draft.markProcessed(action: action)
                            let finalSnapshot = draft.watchSnapshot()
                            try await finalizer.finalize(draft: draft)
                            connectivityProvider.clearWorkoutSnapshot(sessionID: action.payload.session.id, reason: .finalized)
                            let result = WorkoutFinalizedResult(sessionID: action.payload.session.id, success: true)
                            connectivityProvider.sendWorkoutFinalizedResult(result, completion: nil)
                            // End the Live Activity that was started by the launch coordinator
                            WorkoutLiveActivityManager.shared.endActivity(finalSnapshot: finalSnapshot)
                            await reload()
                        } catch {
                            print("Workout finalization failed: \(error)")
                            errorMessage = error.localizedDescription
                            let result = WorkoutFinalizedResult(sessionID: action.payload.session.id, success: false, errorMessage: error.localizedDescription)
                            connectivityProvider.sendWorkoutFinalizedResult(result, completion: nil)
                        }
                    } else {
                        // Draft not found on iPhone — it was likely already finalized.
                        // Send success to watch so it clears its stale state.
                        connectivityProvider.clearWorkoutSnapshot(sessionID: action.payload.session.id, reason: .finalized)
                        let result = WorkoutFinalizedResult(sessionID: action.payload.session.id, success: true)
                        connectivityProvider.sendWorkoutFinalizedResult(result, completion: nil)
                        // Clean up any lingering Live Activity
                        WorkoutLiveActivityManager.shared.endActivity()
                    }
                case .toggleSetCompletion(let completionAction):
                    if var draft = persistenceManager.apply(action: action) {
                        if completionAction.isCompleted {
                            // Extract exercise rest duration to show timer on Live Activity
                            if let exerciseID = ActiveWorkoutDraft.resolveExerciseID(completionAction.reference.exerciseID, routineExerciseID: completionAction.reference.routineExerciseID),
                               let exercise = draft.exercises.first(where: { $0.id == exerciseID }),
                               let restSeconds = exercise.restSeconds, restSeconds > 0 {
                                
                                let restEndDate = Date().addingTimeInterval(TimeInterval(restSeconds))
                                draft.restEndDate = restEndDate
                                draft.restTotalSeconds = restSeconds
                                persistenceManager.save(draft: draft)
                                
                                let snapshot = draft.watchSnapshot(
                                    lastProcessedActionID: action.id,
                                    restEndDate: restEndDate,
                                    restTotalSeconds: restSeconds
                                )
                                WorkoutLiveActivityManager.shared.updateActivity(
                                    snapshot: snapshot,
                                    restEndDate: restEndDate,
                                    restTotalSeconds: restSeconds
                                )
                                
                                // Resync watch so it also sees the timer we just started on phone
                                connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                            } else {
                                // No rest timer, just update Live Activity with current progress
                                let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                                WorkoutLiveActivityManager.shared.updateActivity(snapshot: snapshot)
                                connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                            }
                        } else {
                            // Set was uncompleted, clear timer
                            draft.restEndDate = nil
                            draft.restTotalSeconds = nil
                            persistenceManager.save(draft: draft)
                            
                            let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                            WorkoutLiveActivityManager.shared.updateActivity(snapshot: snapshot)
                            connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                        }
                    }

                case .cancelRestTimer:
                    if let routineID = action.payload.session.routineID,
                       var draft = persistenceManager.load(routineID: routineID),
                       draft.watchSessionPointer.id == action.payload.session.id {
                        draft.apply(watchAction: action) // Now handles clearing rest and marking processed
                        persistenceManager.save(draft: draft)
                        
                        let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                        WorkoutLiveActivityManager.shared.updateActivity(snapshot: snapshot)
                        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                    }

                default:
                    if let draft = persistenceManager.apply(action: action) {
                        // Resync state and update Live Activity for general actions
                        let snapshot = draft.watchSnapshot(lastProcessedActionID: action.id)
                        WorkoutLiveActivityManager.shared.updateActivity(snapshot: snapshot)
                        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
                    }
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

        let sessionPointerID = draft.watchSessionPointer.id
        let wasMounted = activeViewModel?.draft.routineID == routineID

        persistenceManager.clear(routineID: routineID)
        connectivityProvider.clearWorkoutSnapshot(sessionID: sessionPointerID, reason: .finalized)
        WorkoutLiveActivityManager.shared.endActivity(dismissalPolicy: .immediate)

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
            async let routinesTask = dataManager.fetchWorkoutRoutinesSummary()
            async let sessionsTask = dataManager.fetchWorkoutSessions()
            async let analysisTask = dataManager.fetchFitnessAnalysisSummary(daysBack: 29)

            let (routinesSummary, workoutSessions, analysisResponse) = try await (
                routinesTask,
                sessionsTask,
                analysisTask
            )

            let analysis = Self.makeAnalysisSummary(from: analysisResponse)

            guard revision == stateRevision else {
                return
            }

            templates = routinesSummary
            sessions = workoutSessions.map { session in
                WorkoutSessionSummary(
                    id: session.id ?? 0,
                    date: session.date,
                    title: session.session_type,
                    notes: session.notes
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

    private static func makeAnalysisSummary(
        from response: FitnessAnalysisSummaryResponse
    ) -> FitnessAnalysisSummary {
        var totalVolume = 0.0
        var muscleVolumeByBucket = Dictionary(
            uniqueKeysWithValues: FitnessAnalysisSummary.defaultMuscleVolumes.map { ($0.name, 0.0) }
        )

        for ev in response.exercise_volumes {
            totalVolume += ev.volume
            let buckets = bucketNames(for: ev.primary_muscles)
            guard !buckets.isEmpty else { continue }
            
            let splitVolume = ev.volume / Double(buckets.count)
            for bucket in buckets {
                muscleVolumeByBucket[bucket, default: 0] += splitVolume
            }
        }

        let muscleVolumes = FitnessAnalysisSummary.defaultMuscleVolumes.map { muscle in
            FitnessMuscleVolume(
                name: muscle.name,
                volume: muscleVolumeByBucket[muscle.name] ?? 0
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
