import Foundation

@MainActor
final class WatchWorkoutActionQueue {
    private(set) var actions: [WorkoutWatchAction]
    private(set) var isFlushing = false

    private let persistence: WatchWorkoutPersistence
    var onChange: (() -> Void)?
    var onFlushFailure: ((Error) -> Void)?

    init(persistence: WatchWorkoutPersistence) {
        self.persistence = persistence
        self.actions = persistence.loadActions()
    }

    func enqueue(
        payload: WorkoutWatchActionPayload,
        currentSequence: Int
    ) -> WorkoutWatchAction {
        let sequence = max(actions.map(\.sequence).max() ?? 0, currentSequence) + 1
        let action = WorkoutWatchAction(
            id: UUID(),
            timestamp: Date(),
            sequence: sequence,
            payload: payload
        )
        actions.append(action)
        persistAndNotify()
        return action
    }

    func replace(with actions: [WorkoutWatchAction]) {
        self.actions = actions
        persistAndNotify()
    }

    func clear() {
        actions.removeAll()
        isFlushing = false
        persistAndNotify()
    }

    func hasPendingFinish(for sessionID: String) -> Bool {
        actions.contains { action in
            guard case .finishWorkout(let finish) = action.payload else { return false }
            return finish.session.id == sessionID
        }
    }

    func flush(using connectivityManager: ConnectivityManager) {
        guard !isFlushing, !actions.isEmpty, connectivityManager.isReachable else { return }
        isFlushing = true
        onChange?()
        sendNextAction(sentActionIDs: [], using: connectivityManager)
    }

    private func sendNextAction(
        sentActionIDs: Set<UUID>,
        using connectivityManager: ConnectivityManager
    ) {
        guard connectivityManager.isReachable,
              let action = actions
                .sorted(by: { $0.sequence < $1.sequence })
                .first(where: { !sentActionIDs.contains($0.id) }) else {
            isFlushing = false
            onChange?()
            return
        }

        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    var sentActionIDs = sentActionIDs
                    sentActionIDs.insert(action.id)
                    self.sendNextAction(
                        sentActionIDs: sentActionIDs,
                        using: connectivityManager
                    )
                case .failure(let error):
                    self.isFlushing = false
                    self.onChange?()
                    self.onFlushFailure?(error)
                }
            }
        }
    }

    private func persistAndNotify() {
        persistence.saveActions(actions)
        onChange?()
    }
}
