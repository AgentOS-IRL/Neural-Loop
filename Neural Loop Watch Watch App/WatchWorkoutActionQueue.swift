import Foundation

@MainActor
final class WatchWorkoutActionQueue {
    private(set) var actions: [WorkoutWatchAction]
    private(set) var isFlushing = false

    private let persistence: WatchWorkoutPersistence
    var onChange: (() -> Void)?

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

    func flush(using connectivityManager: ConnectivityManager) {
        guard !isFlushing, !actions.isEmpty, connectivityManager.isReachable else { return }
        isFlushing = true
        onChange?()
        sendAction(at: 0, using: connectivityManager)
    }

    private func sendAction(at index: Int, using connectivityManager: ConnectivityManager) {
        guard actions.indices.contains(index), connectivityManager.isReachable else {
            isFlushing = false
            onChange?()
            return
        }

        let action = actions[index]
        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.sendAction(at: index + 1, using: connectivityManager)
                case .failure:
                    self.isFlushing = false
                    self.onChange?()
                }
            }
        }
    }

    private func persistAndNotify() {
        persistence.saveActions(actions)
        onChange?()
    }
}
