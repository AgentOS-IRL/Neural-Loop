import Foundation
import Combine

enum RestTimerState: Equatable {
    case running
    case finished
    case cancelled
}

@MainActor
final class WatchRestTimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int = 0
    @Published var progress: Double = 0
    @Published var timerState: RestTimerState = .running
    @Published var nextSetID: String?

    private var timerCancellable: AnyCancellable?
    private let store: WatchWorkoutStore
    private let exerciseID: String
    private var cancellables = Set<AnyCancellable>()

    init(exerciseID: String, store: WatchWorkoutStore) {
        self.exerciseID = exerciseID
        self.store = store

        // Observe snapshot changes to keep UI in sync with authoritative state
        store.$currentSnapshot
            .sink { [weak self] snapshot in
                self?.updateFromSnapshot(snapshot)
            }
            .store(in: &cancellables)
    }

    func startTicking() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stopTicking() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func cancel() {
        store.cancelRestTimer()
    }

    private func updateFromSnapshot(_ snapshot: ActiveWorkoutSnapshot?) {
        guard let snapshot = snapshot else {
            timerState = .cancelled
            return
        }

        if let restEndDate = snapshot.restEndDate, let total = snapshot.restTotalSeconds {
            timerState = .running
            let remaining = max(0, Int(restEndDate.timeIntervalSince(Date())))
            self.remainingSeconds = remaining
            self.progress = 1.0 - (Double(remaining) / Double(total))
            
            // Find next set
            if let exercise = snapshot.exercises.first(where: { $0.id == exerciseID }) {
                self.nextSetID = exercise.sets.first(where: { !$0.isCompleted })?.id
            }
        } else {
            // Snapshot has no rest timer. 
            // If we were running and still had time left, it was a remote cancel.
            if timerState == .running && remainingSeconds > 0 {
                timerState = .cancelled
            } else if timerState == .running {
                timerState = .finished
            }
        }
    }

    private func tick() {
        guard let snapshot = store.currentSnapshot,
              let restEndDate = snapshot.restEndDate,
              let total = snapshot.restTotalSeconds else {
            return
        }

        let remaining = Int(restEndDate.timeIntervalSince(Date()))
        if remaining <= 0 {
            remainingSeconds = 0
            progress = 1.0
            timerState = .finished
            stopTicking()
        } else {
            remainingSeconds = remaining
            progress = 1.0 - (Double(remaining) / Double(total))
            progress = min(max(progress, 0), 1)
        }
    }
}
