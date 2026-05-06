import Foundation
import WidgetKit

extension UnifiedDataModel {
    func refreshWidgetSnapshot() {
        let snapshot = NeuralLoopWidgetSnapshot(
            tasks: widgetTasks(),
            habits: widgetHabits()
        )

        NeuralLoopWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: NeuralLoopWidgetSnapshot.widgetKind)
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
}
