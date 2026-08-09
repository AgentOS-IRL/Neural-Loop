import Foundation
import Combine

enum RestTimerState: Equatable {
    case running
    case finished
    case cancelled
}

struct RestNextTarget: Equatable {
    let exerciseID: String
    let exerciseName: String
    let setID: String
    let setNumber: Int
    let targetDescription: String?
}

@MainActor
final class WatchRestTimerViewModel: ObservableObject {
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var timerState: RestTimerState = .running
    @Published private(set) var nextSetID: String?
    @Published private(set) var nextTarget: RestNextTarget?

    private var timerCancellable: AnyCancellable?
    private let store: WatchWorkoutStore
    private let exerciseID: String
    private var cancellables = Set<AnyCancellable>()
    private var requestedCancel = false
    private var expectsAdjustedFinish = false

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
        guard timerCancellable == nil else { return }
        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
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
        requestedCancel = true
        store.cancelRestTimer()
    }

    func adjust(by signedSeconds: Int) {
        guard signedSeconds != 0, timerState == .running else { return }
        requestedCancel = false
        expectsAdjustedFinish = remainingSeconds + signedSeconds <= 0
        store.adjustRestTimer(by: signedSeconds)
    }

    private func updateFromSnapshot(_ snapshot: ActiveWorkoutSnapshot?) {
        guard let snapshot else {
            nextTarget = nil
            nextSetID = nil
            timerState = .cancelled
            return
        }

        updateNextTarget(from: snapshot)

        if let restEndDate = snapshot.restEndDate,
           let total = snapshot.restTotalSeconds,
           total > 0 {
            requestedCancel = false
            expectsAdjustedFinish = false
            timerState = .running
            updateClock(restEndDate: restEndDate, total: total)
        } else {
            if expectsAdjustedFinish || (timerState == .running && remainingSeconds == 0) {
                remainingSeconds = 0
                progress = 1
                timerState = .finished
            } else if requestedCancel || timerState == .running {
                timerState = .cancelled
            }
            requestedCancel = false
            expectsAdjustedFinish = false
        }
    }

    private func tick() {
        guard let snapshot = store.currentSnapshot,
              let restEndDate = snapshot.restEndDate,
              let total = snapshot.restTotalSeconds else {
            return
        }

        updateClock(restEndDate: restEndDate, total: total)
        if remainingSeconds <= 0 {
            remainingSeconds = 0
            progress = 1
            timerState = .finished
            stopTicking()
        }
    }

    private func updateClock(restEndDate: Date, total: Int) {
        let remaining = max(
            0,
            Int(restEndDate.timeIntervalSince(Date()).rounded(.up))
        )
        remainingSeconds = remaining
        progress = min(
            max(1 - (Double(remaining) / Double(max(1, total))), 0),
            1
        )
    }

    private func updateNextTarget(from snapshot: ActiveWorkoutSnapshot) {
        let orderedExercises = snapshot.exercises.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex { return lhs.id < rhs.id }
            return lhs.orderIndex < rhs.orderIndex
        }

        let candidates: [ExerciseSnapshot]
        if let currentIndex = orderedExercises.firstIndex(where: { $0.id == exerciseID }) {
            candidates = Array(orderedExercises[currentIndex...])
                + Array(orderedExercises[..<currentIndex])
        } else {
            candidates = orderedExercises
        }

        for exercise in candidates where !exercise.isCompleted {
            guard let set = exercise.sets.first(where: { !$0.isCompleted }) else { continue }
            let target = RestNextTarget(
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                setID: set.id,
                setNumber: set.setNumber,
                targetDescription: targetDescription(
                    for: set,
                    isDurationBased: exercise.isDurationBased == true
                )
            )
            nextTarget = target
            // Existing exercise-detail navigation can only open sets in its own exercise.
            nextSetID = exercise.id == exerciseID ? set.id : nil
            return
        }

        nextTarget = nil
        nextSetID = nil
    }

    private func targetDescription(
        for set: SetSnapshot,
        isDurationBased: Bool
    ) -> String? {
        let values = set.suggestedValues ?? set.previousValues ?? set.values
        if isDurationBased {
            let parts = [
                values.durationMinutes.map { "\($0) min" },
                values.distanceKilometers.map { "\($0) km" },
                values.calories.map { "\($0) kcal" }
            ].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }

        guard values.kg != nil || values.reps != nil else { return nil }
        let reps = values.reps.map { "\($0) reps" } ?? "reps —"
        guard let kg = values.kg else { return reps }
        return "\(kg) kg × \(reps)"
    }
}
