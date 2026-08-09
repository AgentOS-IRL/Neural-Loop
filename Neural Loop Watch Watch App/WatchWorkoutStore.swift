import Foundation
import Combine
import SwiftUI

/// Coordination payload set by WatchSetEntryView after a set is completed,
/// observed by WatchExerciseDetailView to present the rest timer.
struct CompletedSetInfo: Equatable {
    let exerciseID: String
    let setID: String
    let restDurationSeconds: Int
}

@MainActor
final class WatchWorkoutStore: ObservableObject {
    static let shared = WatchWorkoutStore()
    
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
    @Published private(set) var acknowledgedStaleSessionID: String?
    
    // MARK: - Rest Timer State
    // No longer managed locally; driven by currentSnapshot.restEndDate
    
    // MARK: - End Workout State (Plan 528)
    @Published var isFinishing: Bool = false
    @Published var finishError: String?
    
    enum WatchWorkoutSyncState: Equatable {
        case live
        case offlineQueuedEdits(count: Int)
        case syncing
        case finishing
        case finishFailed(String)
        case stale
        case endedRemotely
        case finishQueuedOffline
    }

    var syncState: WatchWorkoutSyncState {
        if isSnapshotStale { return .stale }
        if let error = finishError {
            if error.contains("queued") {
                return .finishQueuedOffline
            }
            return .finishFailed(error)
        }
        if isFinishing { return .finishing }
        if isFlushing { return .syncing }
        if pendingActionCount > 0 { return .offlineQueuedEdits(count: pendingActionCount) }
        return .live
    }
    
    // MARK: - Queue Visibility (Plan 529)
    @Published var pendingActionCount: Int = 0
    
    var isFlushing: Bool { actionQueue.isFlushing }
    private var cancellables = Set<AnyCancellable>()
    private let persistence: WatchWorkoutPersistence
    private let actionQueue: WatchWorkoutActionQueue
    private let displayStateWriter: WatchWorkoutDisplayStateWriter
    let connectivityManager: ConnectivityManager
    
    init(
        connectivityManager: ConnectivityManager? = nil,
        persistence: WatchWorkoutPersistence? = nil,
        displayStateWriter: WatchWorkoutDisplayStateWriter? = nil
    ) {
        let connectivityManager = connectivityManager ?? .shared
        let persistence = persistence ?? WatchWorkoutPersistence()
        let displayStateWriter = displayStateWriter ?? WatchWorkoutDisplayStateWriter()
        self.connectivityManager = connectivityManager
        self.persistence = persistence
        self.actionQueue = WatchWorkoutActionQueue(persistence: persistence)
        self.displayStateWriter = displayStateWriter
        self.currentSnapshot = persistence.loadSnapshot()
        self.acknowledgedStaleSessionID = persistence.loadAcknowledgedStaleSessionID()
        if currentSnapshot?.session.id != acknowledgedStaleSessionID {
            acknowledgedStaleSessionID = nil
            persistence.saveAcknowledgedStaleSessionID(nil)
        }
        self.pendingActionCount = actionQueue.actions.count
        self.actionQueue.onChange = { [weak self] in
            guard let self else { return }
            self.pendingActionCount = self.actionQueue.actions.count
            self.objectWillChange.send()
        }
        self.actionQueue.onFlushFailure = { [weak self] _ in
            guard let self, self.isFinishing else { return }
            self.isFinishing = false
            self.finishError = "Couldn’t sync workout. Try again."
        }
        connectivityManager.checkApplicationContext()
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                if let snapshot {
                    self.reconcile(with: snapshot)
                }
            }
            .store(in: &cancellables)
            
        connectivityManager.clearedWorkoutHandler = { [weak self] cleared in
            guard let self = self else { return }
            if self.currentSnapshot?.session.id == cleared.sessionID {
                self.clearStore()
                // If it was cancelled on phone or replaced, we could potentially show an alert
            }
        }
            
        connectivityManager.$isReachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReachable in
                if isReachable {
                    self?.flushQueue()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to finalization results from iPhone
        connectivityManager.finalizationHandler = { [weak self] result in
            guard let self else { return }
            self.handleFinalizationResult(result)
        }
    }
    
    // MARK: - Finalization Result Handling
    
    private func handleFinalizationResult(_ result: WorkoutFinalizedResult) {
        guard let currentSnapshot, currentSnapshot.session.id == result.sessionID else { return }
        
        if result.success {
            clearStore()
        } else {
            isFinishing = false
            finishError = result.errorMessage ?? "Workout could not be saved"
        }
    }
    
    // MARK: - Actions
    
    func updateSetValues(
        exerciseID: String,
        setID: String,
        kg: Decimal? = nil,
        reps: Int? = nil,
        durationMinutes: Decimal? = nil,
        distanceKilometers: Decimal? = nil,
        calories: Decimal? = nil
    ) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID, setID: setID)
        let values = WorkoutSetValuesSnapshot(
            kg: kg,
            reps: reps,
            durationMinutes: durationMinutes,
            distanceKilometers: distanceKilometers,
            calories: calories
        )
        let payload = WorkoutWatchActionPayload.updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        enqueueAction(payload: payload)
    }
    
    func toggleSetCompletion(exerciseID: String, setID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID, setID: setID)
        let payload = WorkoutWatchActionPayload.toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func addSet(exerciseID: String) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID)
        let payload = WorkoutWatchActionPayload.addSet(reference)
        enqueueAction(payload: payload)
    }
    
    func toggleExerciseCompletion(exerciseID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let routineID = currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.routineExerciseID
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID, routineExerciseID: routineID)
        let payload = WorkoutWatchActionPayload.updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func finishWorkout() {
        guard let session = currentSnapshot?.session else { return }
        guard !isFinishing else { return }
        isFinishing = true
        finishError = nil

        if actionQueue.hasPendingFinish(for: session.id) {
            flushQueue()
        } else {
            let payload = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
            enqueueAction(payload: payload)
        }
        
        if !connectivityManager.isReachable {
            finishError = "Workout finish queued. Open iPhone to sync."
            isFinishing = false
        }
    }
    
    func retryFinish() {
        guard let session = currentSnapshot?.session, !isFinishing else { return }
        isFinishing = true
        finishError = nil

        if actionQueue.hasPendingFinish(for: session.id) {
            flushQueue()
        } else {
            enqueueAction(
                payload: .finishWorkout(WorkoutWatchSessionAction(session: session))
            )
        }
        
        if !connectivityManager.isReachable {
            finishError = "Workout finish queued. Open iPhone to sync."
            isFinishing = false
        }
    }
    
    func cancelRestTimer() {
        guard let session = currentSnapshot?.session else { return }
        let payload = WorkoutWatchActionPayload.cancelRestTimer(WorkoutWatchSessionAction(session: session))
        enqueueAction(payload: payload)
    }

    func adjustRestTimer(by signedSeconds: Int) {
        guard signedSeconds != 0,
              currentSnapshot?.restEndDate != nil,
              let session = currentSnapshot?.session else { return }

        let payload = WorkoutWatchActionPayload.adjustRestTimer(
            WorkoutWatchRestTimerAdjustmentAction(
                session: session,
                signedSeconds: signedSeconds
            )
        )
        enqueueAction(payload: payload)
    }

    private func enqueueAction(payload: WorkoutWatchActionPayload) {
        let action = actionQueue.enqueue(
            payload: payload,
            currentSequence: currentSnapshot?.lastProcessedWatchSequence ?? 0
        )
        applyOptimisticAction(action)
        flushQueue()
    }

    private func applyOptimisticAction(_ action: WorkoutWatchAction) {
        guard let snapshot = currentSnapshot else { return }
        currentSnapshot = WatchWorkoutSnapshotReducer.applying(action, to: snapshot)
        persistCurrentSnapshot()
    }

    private func reconcile(with authoritativeSnapshot: ActiveWorkoutSnapshot) {
        let previousSessionID = currentSnapshot?.session.id
        switch WatchWorkoutSnapshotReducer.reconcile(
            current: currentSnapshot,
            authoritative: authoritativeSnapshot,
            pendingActions: actionQueue.actions
        ) {
        case .ignored:
            return
        case .accepted(let snapshot, let pendingActions):
            if previousSessionID != snapshot.session.id {
                resetStaleAcknowledgement()
            }
            actionQueue.replace(with: pendingActions)
            currentSnapshot = snapshot
            persistCurrentSnapshot()
        }
    }

    func flushQueue() {
        actionQueue.flush(using: connectivityManager)
    }

    private func persistCurrentSnapshot() {
        persistence.saveSnapshot(currentSnapshot)
        displayStateWriter.write(snapshot: currentSnapshot)
    }
    
    func clearStore() {
        self.currentSnapshot = nil
        self.actionQueue.clear()
        self.pendingActionCount = 0
        self.isFinishing = false
        self.finishError = nil
        self.acknowledgedStaleSessionID = nil
        persistence.clear()
        displayStateWriter.clear()
    }
    
    // MARK: - Stale Draft Detection (Plan 529)
    
    var isSnapshotStale: Bool {
        guard let snapshot = currentSnapshot,
              snapshot.session.id != acknowledgedStaleSessionID else { return false }
        return isOlderThanStaleThreshold(snapshot)
    }
    
    var staleSnapshotAge: String? {
        guard let startedAt = currentSnapshot?.startedAt else { return nil }
        let hours = Int(Date().timeIntervalSince(startedAt) / 3600)
        if hours < 24 { return nil }
        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
    
    func discardStaleWorkout() {
        clearStore()
    }

    func continueStaleWorkout() {
        guard let snapshot = currentSnapshot,
              isOlderThanStaleThreshold(snapshot) else { return }

        acknowledgedStaleSessionID = snapshot.session.id
        persistence.saveAcknowledgedStaleSessionID(snapshot.session.id)

        // Consume the latest durable context before explicitly asking the
        // iPhone for its current authoritative snapshot.
        connectivityManager.checkApplicationContext()
        enqueueAction(
            payload: .requestSnapshot(WorkoutWatchSessionAction(session: snapshot.session))
        )
    }

    private func resetStaleAcknowledgement() {
        acknowledgedStaleSessionID = nil
        persistence.saveAcknowledgedStaleSessionID(nil)
    }

    private func isOlderThanStaleThreshold(_ snapshot: ActiveWorkoutSnapshot) -> Bool {
        guard let startedAt = snapshot.startedAt else { return false }
        return Date().timeIntervalSince(startedAt) > 24 * 3600
    }

}
