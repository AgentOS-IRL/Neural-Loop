import Foundation

struct WorkoutSessionLoader {
    private let db: any WorkoutLaunchHistoryReading

    init(db: any WorkoutLaunchHistoryReading) {
        self.db = db
    }

    func loadHistory(
        for exercises: [WorkoutExerciseCardState],
        routineID: Int64?
    ) async -> [WorkoutExerciseCardState] {
        guard !exercises.isEmpty else { return exercises }

        let lookupItems = exercises.map {
            WorkoutLaunchHistoryLookupItem(
                routine_exercise_id: $0.id,
                exercise_id: $0.exercise.id,
                exercise_type: $0.exercise.type
            )
        }

        do {
            let snapshots = try await db.fetchWorkoutLaunchHistory(
                routineID: routineID,
                lookupItems: lookupItems
            )
            let snapshotsByRoutineExerciseID = Dictionary(
                uniqueKeysWithValues: snapshots.map { ($0.routine_exercise_id, $0) }
            )

            return exercises.map { exercise in
                guard let snapshot = snapshotsByRoutineExerciseID[exercise.id] else {
                    return exercise
                }
                return apply(snapshot: snapshot, to: exercise)
            }
        } catch {
            return exercises.map { exercise in
                var updated = exercise
                updated.historyUnavailable = true
                updated.historicalHint = "History unavailable"
                return updated
            }
        }
    }

    private func apply(
        snapshot: WorkoutLaunchHistorySnapshot,
        to exercise: WorkoutExerciseCardState
    ) -> WorkoutExerciseCardState {
        var updated = exercise

        if let scope = snapshot.source_scope,
           let dateString = snapshot.source_date,
           let date = WorkoutDateCoding.date(from: dateString),
           let sessionID = snapshot.source_session_id {
            updated.historySource = WorkoutHistorySource(scope: scope, date: date, sessionID: sessionID)
            updated.historicalHint = updated.historySource?.label
        }

        if exercise.exercise.isRepBased {
            applyStrengthHistory(snapshot.strength_sets, to: &updated)
        } else {
            applyCardioHistory(snapshot.cardio_logs, to: &updated)
        }

        return updated
    }

    private func applyStrengthHistory(
        _ history: [WorkoutLaunchHistoryStrengthSet],
        to exercise: inout WorkoutExerciseCardState
    ) {
        let workingHistory = history.filter { $0.set_type == .working }
        let warmupHistory = history.filter { $0.set_type == .warmup }
        let reason = workingSuggestionReason(
            history: workingHistory,
            range: exercise.effectiveTargetRepRange
        )
        for index in exercise.sets.indices {
            let set = exercise.sets[index]
            let matchingHistory = set.setType == .warmup ? warmupHistory : workingHistory
            guard let previous = historicalStrengthSet(
                number: set.setNumber,
                in: matchingHistory
            ) else { continue }

            let previousValues = WorkoutDraftValues(weight: previous.weight, reps: previous.reps)
            exercise.sets[index].previousValues = previousValues

            if set.setType == .warmup {
                exercise.sets[index].suggestedValues = previousValues
                exercise.sets[index].suggestionReason = .warmupRepeat
                continue
            }

            guard let reason else {
                exercise.sets[index].suggestedValues = previousValues
                continue
            }

            exercise.sets[index].suggestionReason = reason
            exercise.sets[index].suggestedValues = strengthSuggestion(
                from: previous,
                range: exercise.effectiveTargetRepRange,
                increment: exercise.loadIncrementKg ?? 2.5,
                reason: reason
            )
        }
    }

    private func workingSuggestionReason(
        history: [WorkoutLaunchHistoryStrengthSet],
        range: WorkoutRepRange?
    ) -> WorkoutSuggestionReason? {
        guard !history.isEmpty, let range else { return nil }
        let isBodyweight = history.allSatisfy { ($0.weight ?? 0) <= 0 }
        let allAtCeiling = history.allSatisfy { $0.reps >= range.maximum }
        let allAtMinimum = history.allSatisfy { $0.reps >= range.minimum }

        if allAtCeiling {
            return isBodyweight ? .bodyweightRangeComplete : .rangeCeilingLoadIncrease
        }
        if allAtMinimum {
            return isBodyweight ? .bodyweightRepIncrease : .withinRangeRepIncrease
        }
        return .belowMinimumRepeat
    }

    private func strengthSuggestion(
        from previous: WorkoutLaunchHistoryStrengthSet,
        range: WorkoutRepRange?,
        increment: Decimal,
        reason: WorkoutSuggestionReason
    ) -> WorkoutDraftValues {
        guard let range else {
            return WorkoutDraftValues(weight: previous.weight, reps: previous.reps)
        }

        switch reason {
        case .rangeCeilingLoadIncrease:
            return WorkoutDraftValues(
                weight: (previous.weight ?? 0) + increment,
                reps: range.minimum
            )
        case .withinRangeRepIncrease, .bodyweightRepIncrease:
            return WorkoutDraftValues(
                weight: previous.weight,
                reps: min(previous.reps + 1, range.maximum)
            )
        case .bodyweightRangeComplete:
            return WorkoutDraftValues(weight: nil, reps: min(previous.reps, range.maximum))
        case .belowMinimumRepeat, .warmupRepeat:
            return WorkoutDraftValues(weight: previous.weight, reps: previous.reps)
        case .cardioRepeat:
            return WorkoutDraftValues()
        }
    }

    private func historicalStrengthSet(
        number: Int,
        in history: [WorkoutLaunchHistoryStrengthSet]
    ) -> WorkoutLaunchHistoryStrengthSet? {
        let ordered = history.sorted { $0.set_number < $1.set_number }
        if let exact = ordered.first(where: { $0.set_number == number }) {
            return exact
        }
        guard let last = ordered.last, number > last.set_number else { return nil }
        return last
    }

    private func applyCardioHistory(
        _ history: [WorkoutLaunchHistoryCardioLog],
        to exercise: inout WorkoutExerciseCardState
    ) {
        for index in exercise.sets.indices {
            let setNumber = exercise.sets[index].setNumber
            guard let previous = historicalCardioLog(number: setNumber, in: history) else { continue }
            let values = WorkoutDraftValues(
                durationMinutes: previous.duration_minutes,
                distanceKilometers: previous.distance_meters.map { $0 / 1000 },
                calories: previous.calories
            )
            exercise.sets[index].previousValues = values
            exercise.sets[index].suggestedValues = values
            exercise.sets[index].suggestionReason = .cardioRepeat
        }
    }

    private func historicalCardioLog(
        number: Int,
        in history: [WorkoutLaunchHistoryCardioLog]
    ) -> WorkoutLaunchHistoryCardioLog? {
        let ordered = history.sorted { $0.set_number < $1.set_number }
        if let exact = ordered.first(where: { $0.set_number == number }) {
            return exact
        }
        guard let last = ordered.last, number > last.set_number else { return nil }
        return last
    }
}
