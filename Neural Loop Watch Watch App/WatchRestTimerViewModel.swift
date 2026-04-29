import Foundation
import Combine

enum RestTimerState: Equatable {
    case running
    case finished
    case cancelled
}

@MainActor
final class WatchRestTimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int
    @Published var progress: Double = 0
    @Published var timerState: RestTimerState = .running
    @Published var nextSetID: String?

    let totalSeconds: Int
    let exerciseID: String
    let completedSetID: String

    private var timerCancellable: AnyCancellable?
    private weak var store: WatchWorkoutStore?

    /// Production init — resolves next set from the store's current snapshot.
    init(totalSeconds: Int, exerciseID: String, completedSetID: String, store: WatchWorkoutStore) {
        self.totalSeconds = max(totalSeconds, 0)
        self.exerciseID = exerciseID
        self.completedSetID = completedSetID
        self.remainingSeconds = max(totalSeconds, 0)
        self.store = store

        if let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID }) {
            self.nextSetID = Self.resolveNextIncompleteSet(in: exercise, after: completedSetID)
        }
    }

    /// Test-friendly init — allows direct injection of nextSetID.
    init(totalSeconds: Int, exerciseID: String, completedSetID: String, nextSetID: String?) {
        self.totalSeconds = max(totalSeconds, 0)
        self.exerciseID = exerciseID
        self.completedSetID = completedSetID
        self.remainingSeconds = max(totalSeconds, 0)
        self.nextSetID = nextSetID
        self.store = nil
    }

    func start() {
        guard totalSeconds > 0 else {
            timerState = .finished
            progress = 1.0
            remainingSeconds = 0
            store?.persistDisplayStateAndReloadWidgets()
            return
        }

        timerState = .running
        // Persist the rest state so the complication shows the countdown
        let restEnd = Date().addingTimeInterval(TimeInterval(totalSeconds))
        store?.persistDisplayStateAndReloadWidgets(restEndDate: restEnd, restTotalSeconds: totalSeconds)
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.tick()
                }
            }
    }

    func cancel() {
        timerState = .cancelled
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Next-Set Resolution (pure, static, testable)

    static func resolveNextIncompleteSet(in exercise: ExerciseSnapshot, after setID: String) -> String? {
        guard let currentIndex = exercise.sets.firstIndex(where: { $0.id == setID }) else {
            return nil
        }

        let startIndex = exercise.sets.index(after: currentIndex)
        for i in startIndex..<exercise.sets.endIndex {
            if !exercise.sets[i].isCompleted {
                return exercise.sets[i].id
            }
        }

        return nil
    }

    // MARK: - Private

    private func tick() {
        guard timerState == .running else { return }

        remainingSeconds -= 1
        if totalSeconds > 0 {
            progress = 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
            progress = min(max(progress, 0), 1)
        }

        if remainingSeconds <= 0 {
            remainingSeconds = 0
            progress = 1.0
            timerState = .finished
            timerCancellable?.cancel()
            timerCancellable = nil
            store?.persistDisplayStateAndReloadWidgets()
        }
    }
}
