import Foundation

struct GoalProgressSnapshot: Equatable {
    let current: Double
    let target: Double
    let label: String
    let percentage: Double
    let chartRecords: [Date: Double]

    static let empty = GoalProgressSnapshot(
        current: 0,
        target: 0,
        label: "",
        percentage: 0,
        chartRecords: [:]
    )
}

struct GoalProgressPoint: Identifiable, Equatable {
    let id: Date
    let date: Date
    let value: Double

    init(date: Date, value: Double) {
        self.id = date
        self.date = date
        self.value = value
    }
}

enum GoalProgressCalculator {
    static func snapshot(
        goalId: Int64,
        tracking: GoalsTracking?,
        tasks: [Tasks],
        subGoals: [Goals],
        customRecords: [GoalsTrackingRecord]? = nil,
        calendar: Calendar = .neuralLoopDisplay
    ) -> GoalProgressSnapshot {
        guard let tracking, !tracking.isEmpty else {
            return .empty
        }

        switch tracking.type {
        case .custom:
            return customSnapshot(tracking: tracking, records: customRecords, calendar: calendar)
        case .task:
            return taskSnapshot(tasks: tasks, calendar: calendar)
        case .sub_goal:
            return subGoalSnapshot(subGoals: subGoals, calendar: calendar)
        case .unknown:
            return .empty
        }
    }

    private static func customSnapshot(
        tracking: GoalsTracking,
        records: [GoalsTrackingRecord]?,
        calendar: Calendar
    ) -> GoalProgressSnapshot {
        let target = tracking.target ?? 0
        let label = tracking.label ?? "Times"
        guard let records, !records.isEmpty else {
            let current = tracking.value ?? 0
            return GoalProgressSnapshot(
                current: current,
                target: target,
                label: label,
                percentage: percentage(current: current, target: target),
                chartRecords: [:]
            )
        }

        var runningTotal = 0.0
        var chartRecords: [Date: Double] = [:]

        for record in records.sorted(by: recordSort) {
            guard let createdAt = record.created_at else { continue }
            runningTotal += record.value
            chartRecords[calendar.startOfDay(for: createdAt)] = runningTotal
        }

        let current = runningTotal
        return GoalProgressSnapshot(
            current: current,
            target: target,
            label: label,
            percentage: percentage(current: current, target: target),
            chartRecords: chartRecords
        )
    }

    private static func taskSnapshot(tasks: [Tasks], calendar: Calendar) -> GoalProgressSnapshot {
        let completedTasks = tasks.filter(\.is_completed)
        var chartRecords: [Date: Double] = [:]

        for task in completedTasks {
            guard let progressDate = task.completed_at ?? task.updated_at else { continue }
            chartRecords[calendar.startOfDay(for: progressDate), default: 0] += 1
        }

        let current = Double(completedTasks.count)
        let target = Double(tasks.count)
        return GoalProgressSnapshot(
            current: current,
            target: target,
            label: "Tasks",
            percentage: percentage(current: current, target: target),
            chartRecords: chartRecords
        )
    }

    private static func subGoalSnapshot(subGoals: [Goals], calendar: Calendar) -> GoalProgressSnapshot {
        let completedGoals = subGoals.filter(\.is_completed)
        var chartRecords: [Date: Double] = [:]

        for goal in completedGoals {
            chartRecords[calendar.startOfDay(for: goal.updated_at), default: 0] += 1
        }

        let current = Double(completedGoals.count)
        let target = Double(subGoals.count)
        return GoalProgressSnapshot(
            current: current,
            target: target,
            label: "Goals",
            percentage: percentage(current: current, target: target),
            chartRecords: chartRecords
        )
    }

    private static func percentage(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    private static func recordSort(_ lhs: GoalsTrackingRecord, _ rhs: GoalsTrackingRecord) -> Bool {
        switch (lhs.created_at, rhs.created_at) {
        case let (lhsDate?, rhsDate?):
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return (lhs.id ?? 0) < (rhs.id ?? 0)
        }
    }
}
