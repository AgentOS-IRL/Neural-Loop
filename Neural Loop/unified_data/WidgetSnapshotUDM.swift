import Foundation
import WidgetKit

extension UnifiedDataModel {
    func updateDailyLoopRecurringCompletions(_ completions: [CompletedRecurringTask]) {
        dailyLoopRecurringCompletions = completions
        refreshWidgetSnapshot()
    }

    func refreshWidgetSnapshot() {
        let snapshot = NeuralLoopWidgetSnapshot(
            tasks: widgetTasks(),
            habits: widgetHabits()
        )

        let dailyLoopSnapshot = makeDailyLoopWatchSnapshot()

        NeuralLoopWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: NeuralLoopWidgetSnapshot.widgetKind)
        ConnectivityManager.shared.sendDailyLoopSnapshot(dailyLoopSnapshot)
    }

    func makeDailyLoopWatchSnapshot(now: Date = .now) -> DailyLoopWatchSnapshot {
        DailyLoopWatchSnapshot(
            tasks: dailyLoopWatchTasks(now: now),
            habits: dailyLoopWatchHabits(now: now)
        )
    }

    private func widgetTasks() -> [NeuralLoopWidgetTask] {
        let calendar = Calendar.neuralLoopDisplay
        let todayEnd = calendar.endOfDay(.now)

        return tasks
            .filter { task in
                guard !task.is_completed else { return false }
                guard let startDate = task.start_date else { return true }
                return startDate <= todayEnd
            }
            .sorted { lhs, rhs in
                switch (lhs.start_date, rhs.start_date) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate < rhsDate
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return lhs.priority > rhs.priority
                }
            }
            .prefix(8)
            .map {
                NeuralLoopWidgetTask(
                    id: $0.id,
                    title: $0.title,
                    startDate: $0.start_date,
                    duration: $0.duration,
                    priority: $0.priority
                )
            }
    }

    private func widgetHabits() -> [NeuralLoopWidgetHabit] {
        habits
            .filter {
                guard let id = $0.id else { return false }
                return HabitWindow.isOccurring(on: .now, habit: $0)
                    && currentHabitProgressMap[id] != nil
            }
            .map { habit in
                let progress = currentHabitProgressMap[habit.id ?? -1]
                let skipped = habit.id.map {
                    HabitSkipPersistenceManager.shared.isHabitSkippedToday(habitId: $0)
                } ?? false

                return NeuralLoopWidgetHabit(
                    id: habit.id,
                    title: habit.title,
                    current: progress?.current ?? 0,
                    target: max(progress?.target ?? habit.target, 1),
                    label: progress?.targetLabel ?? habit.label,
                    priority: habit.priority,
                    isSkippedToday: skipped
                )
            }
            .sorted { lhs, rhs in
                if lhs.isSkippedToday != rhs.isSkippedToday {
                    return !lhs.isSkippedToday
                }

                if lhs.isComplete != rhs.isComplete {
                    return !lhs.isComplete
                }

                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(8)
            .map { $0 }
    }

    private func dailyLoopWatchTasks(now: Date = .now) -> [DailyLoopWatchTaskSummary] {
        let calendar = Calendar.neuralLoopDisplay
        let todayEnd = calendar.endOfDay(now)

        return tasks.compactMap { task -> DailyLoopWatchTaskSummary? in
            guard let taskID = task.id else { return nil }

            let isRecurring = task.recursion_rule?.isEmpty == false
            let occurrenceStart: Date?
            let displayStart: Date?

            if isRecurring {
                guard let resolvedOccurrence = recurringTaskOccurrenceStart(
                    for: task,
                    on: now,
                    calendar: calendar
                ) else {
                    return nil
                }
                occurrenceStart = resolvedOccurrence
                displayStart = resolvedOccurrence
            } else {
                if task.is_completed {
                    guard task.completed_at.map({ calendar.isDate($0, inSameDayAs: now) }) == true else {
                        return nil
                    }
                } else {
                    guard task.start_date.map({ $0 <= todayEnd }) ?? true else { return nil }
                }
                occurrenceStart = nil
                displayStart = task.start_date
            }

            return DailyLoopWatchTaskSummary(
                identity: DailyLoopTaskIdentity(
                    taskID: taskID,
                    occurrenceStart: occurrenceStart
                ),
                title: task.title,
                startDate: displayStart,
                duration: task.duration,
                priority: task.priority,
                recurrenceRule: task.recursion_rule,
                isCompleted: occurrenceStart.map {
                    isRecurringTaskCompleted(
                        taskId: taskID,
                        occurrenceStart: $0,
                        completions: dailyLoopRecurringCompletions
                    )
                } ?? task.is_completed
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.startDate, rhs.startDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private func dailyLoopWatchHabits(now: Date = .now) -> [DailyLoopWatchHabitSummary] {
        habits.compactMap { habit -> DailyLoopWatchHabitSummary? in
            guard
                let habitID = habit.id,
                HabitWindow.isOccurring(on: now, habit: habit),
                let progress = currentHabitProgressMap[habitID]
            else {
                return nil
            }

            return DailyLoopWatchHabitSummary(
                id: habitID,
                title: habit.title,
                current: progress.current,
                target: max(progress.target, 1),
                label: progress.targetLabel.isEmpty ? habit.label : progress.targetLabel,
                priority: habit.priority,
                isSkipped: HabitSkipPersistenceManager.shared.isHabitSkippedToday(habitId: habitID)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isSkipped != rhs.isSkipped {
                return !lhs.isSkipped
            }
            if lhs.isComplete != rhs.isComplete {
                return !lhs.isComplete
            }
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
