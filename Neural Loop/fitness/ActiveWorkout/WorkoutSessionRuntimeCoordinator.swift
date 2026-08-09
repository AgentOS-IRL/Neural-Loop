import Foundation
import ActivityKit

@MainActor
protocol WorkoutLiveActivityProviding {
    func start(snapshot: ActiveWorkoutSnapshot)
    func update(snapshot: ActiveWorkoutSnapshot)
    func end(finalSnapshot: ActiveWorkoutSnapshot?)
    func endImmediately()
}

@MainActor
struct WorkoutLiveActivityAdapter: WorkoutLiveActivityProviding {
    func start(snapshot: ActiveWorkoutSnapshot) {
        WorkoutLiveActivityManager.shared.startActivity(
            snapshot: snapshot,
            restEndDate: snapshot.restEndDate,
            restTotalSeconds: snapshot.restTotalSeconds
        )
    }

    func update(snapshot: ActiveWorkoutSnapshot) {
        WorkoutLiveActivityManager.shared.updateActivity(
            snapshot: snapshot,
            restEndDate: snapshot.restEndDate,
            restTotalSeconds: snapshot.restTotalSeconds
        )
    }

    func end(finalSnapshot: ActiveWorkoutSnapshot?) {
        WorkoutLiveActivityManager.shared.endActivity(finalSnapshot: finalSnapshot)
    }

    func endImmediately() {
        WorkoutLiveActivityManager.shared.endActivity(dismissalPolicy: .immediate)
    }
}

enum WorkoutRuntimeActionOutcome {
    case ignored
    case updated(ActiveWorkoutDraft)
    case finalized
}

enum WorkoutSessionRuntimeError: LocalizedError {
    case finalizerUnavailable

    var errorDescription: String? {
        switch self {
        case .finalizerUnavailable:
            return "Workout finalization is unavailable."
        }
    }
}

final class NoopWorkoutConnectivityProvider: WorkoutConnectivityProviding {
    static let shared = NoopWorkoutConnectivityProvider()

    private init() {}

    func sendWorkoutSnapshot(
        _ snapshot: ActiveWorkoutSnapshot,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        completion?(.success(()))
    }

    func sendWorkoutAction(
        _ action: WorkoutWatchAction,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        completion?(.success(()))
    }

    func sendWorkoutFinalizedResult(
        _ result: WorkoutFinalizedResult,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        completion?(.success(()))
    }

    func clearWorkoutSnapshot(sessionID: String, reason: ClearReason) {}
}

@MainActor
protocol WorkoutSessionRuntimeCoordinating: AnyObject {
    var persistenceManager: WorkoutDraftPersistenceManager { get }

    func start(_ draft: ActiveWorkoutDraft)
    func publish(_ draft: ActiveWorkoutDraft, acknowledging actionID: UUID?)
    func finish(_ draft: ActiveWorkoutDraft) async throws
    func discard(_ draft: ActiveWorkoutDraft, reason: ClearReason)
    func handleBackground(action: WorkoutWatchAction) async throws -> WorkoutRuntimeActionOutcome
}

@MainActor
final class WorkoutSessionRuntimeCoordinator: WorkoutSessionRuntimeCoordinating {
    let persistenceManager: WorkoutDraftPersistenceManager

    private let connectivityProvider: any WorkoutConnectivityProviding
    private let finalizer: (any WorkoutSessionFinalizing)?
    private let liveActivity: any WorkoutLiveActivityProviding

    init(
        persistenceManager: WorkoutDraftPersistenceManager,
        connectivityProvider: any WorkoutConnectivityProviding,
        finalizer: (any WorkoutSessionFinalizing)? = nil,
        liveActivity: (any WorkoutLiveActivityProviding)? = nil
    ) {
        self.persistenceManager = persistenceManager
        self.connectivityProvider = connectivityProvider
        self.finalizer = finalizer
        self.liveActivity = liveActivity ?? WorkoutLiveActivityAdapter()
    }

    func start(_ draft: ActiveWorkoutDraft) {
        persistenceManager.save(draft: draft)
        persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)

        let snapshot = draft.watchSnapshot()
        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
        liveActivity.start(snapshot: snapshot)
    }

    func publish(_ draft: ActiveWorkoutDraft, acknowledging actionID: UUID? = nil) {
        persistenceManager.save(draft: draft)

        let snapshot = draft.watchSnapshot(
            lastProcessedActionID: actionID,
            restEndDate: draft.restEndDate,
            restTotalSeconds: draft.restTotalSeconds
        )
        connectivityProvider.sendWorkoutSnapshot(snapshot, completion: nil)
        liveActivity.update(snapshot: snapshot)
    }

    func finish(_ draft: ActiveWorkoutDraft) async throws {
        guard let finalizer else {
            throw WorkoutSessionRuntimeError.finalizerUnavailable
        }

        do {
            let finalSnapshot = draft.watchSnapshot()
            try await finalizer.finalize(draft: draft)
            connectivityProvider.clearWorkoutSnapshot(
                sessionID: draft.watchSessionPointer.id,
                reason: .finalized
            )
            connectivityProvider.sendWorkoutFinalizedResult(
                WorkoutFinalizedResult(sessionID: draft.watchSessionPointer.id, success: true),
                completion: nil
            )
            liveActivity.end(finalSnapshot: finalSnapshot)
        } catch {
            connectivityProvider.sendWorkoutFinalizedResult(
                WorkoutFinalizedResult(
                    sessionID: draft.watchSessionPointer.id,
                    success: false,
                    errorMessage: error.localizedDescription
                ),
                completion: nil
            )
            throw error
        }
    }

    func discard(_ draft: ActiveWorkoutDraft, reason: ClearReason) {
        persistenceManager.clear(routineID: draft.routineID)
        connectivityProvider.clearWorkoutSnapshot(
            sessionID: draft.watchSessionPointer.id,
            reason: reason
        )
        liveActivity.endImmediately()
    }

    func handleBackground(action: WorkoutWatchAction) async throws -> WorkoutRuntimeActionOutcome {
        guard let routineID = action.payload.session.routineID,
              var draft = persistenceManager.load(routineID: routineID),
              draft.watchSessionPointer.id == action.payload.session.id else {
            if case .finishWorkout = action.payload {
                connectivityProvider.clearWorkoutSnapshot(
                    sessionID: action.payload.session.id,
                    reason: .finalized
                )
                connectivityProvider.sendWorkoutFinalizedResult(
                    WorkoutFinalizedResult(sessionID: action.payload.session.id, success: true),
                    completion: nil
                )
                liveActivity.end(finalSnapshot: nil)
                return .finalized
            }
            return .ignored
        }

        guard !draft.processedWatchActionIDs.contains(action.id) else {
            publish(draft)
            return .ignored
        }

        guard action.sequence == draft.lastProcessedWatchSequence + 1 || action.sequence == 0 else {
            publish(draft)
            return .ignored
        }

        switch action.payload {
        case .finishWorkout:
            draft.markProcessed(action: action)
            try await finish(draft)
            return .finalized

        case .toggleSetCompletion(let completionAction):
            draft.apply(watchAction: action)

            if completionAction.isCompleted,
               let exerciseID = ActiveWorkoutDraft.resolveExerciseID(
                   completionAction.reference.exerciseID,
                   routineExerciseID: completionAction.reference.routineExerciseID
               ),
               let setID = UUID(uuidString: completionAction.reference.setID),
               let exercise = draft.exercises.first(where: { $0.id == exerciseID }),
               exercise.sets.first(where: { $0.id == setID })?.isCompleted == true,
               let restSeconds = exercise.restSeconds,
               restSeconds > 0 {
                draft.restEndDate = Date().addingTimeInterval(TimeInterval(restSeconds))
                draft.restTotalSeconds = restSeconds
            } else if !completionAction.isCompleted {
                draft.restEndDate = nil
                draft.restTotalSeconds = nil
            }

        case .adjustRestTimer:
            draft.apply(watchAction: action)

        default:
            draft.apply(watchAction: action)
        }

        publish(draft, acknowledging: action.id)
        return .updated(draft)
    }
}
