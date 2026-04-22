import XCTest
@testable import Neural_Loop

final class GoalProgressCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCustomProgressAccumulatesDecimalRecordsInDateOrder() {
        let day1 = date(year: 2026, month: 4, day: 20, hour: 9)
        let day2 = date(year: 2026, month: 4, day: 21, hour: 9)
        let tracking = customTracking(target: 5, label: "Hours")
        let records = [
            customRecord(id: 2, value: 2.25, createdAt: day2, label: "Hours"),
            customRecord(id: 1, value: 1.5, createdAt: day1, label: "Hours")
        ]

        let snapshot = GoalProgressCalculator.snapshot(
            goalId: 10,
            tracking: tracking,
            tasks: [],
            subGoals: [],
            customRecords: records,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.current, 3.75)
        XCTAssertEqual(snapshot.target, 5)
        XCTAssertEqual(snapshot.label, "Hours")
        XCTAssertEqual(snapshot.percentage, 0.75)
        XCTAssertEqual(snapshot.chartRecords[calendar.startOfDay(for: day1)], 1.5)
        XCTAssertEqual(snapshot.chartRecords[calendar.startOfDay(for: day2)], 3.75)
    }

    func testCustomSnapshotUsesTrackingLabel() {
        let snapshot = GoalProgressCalculator.snapshot(
            goalId: 10,
            tracking: customTracking(target: 10, label: "Miles"),
            tasks: [],
            subGoals: [],
            calendar: calendar
        )

        XCTAssertEqual(snapshot.label, "Miles")
    }

    func testTaskProgressCountsCompletedTasksAndAccumulatesSameDayCompletions() {
        let completionDate = date(year: 2026, month: 4, day: 20, hour: 11)
        let snapshot = GoalProgressCalculator.snapshot(
            goalId: 10,
            tracking: tracking(type: .task),
            tasks: [
                task(id: 1, isCompleted: true, completedAt: completionDate),
                task(id: 2, isCompleted: true, completedAt: completionDate),
                task(id: 3, isCompleted: false, completedAt: nil)
            ],
            subGoals: [],
            calendar: calendar
        )

        XCTAssertEqual(snapshot.current, 2)
        XCTAssertEqual(snapshot.target, 3)
        XCTAssertEqual(snapshot.label, "Tasks")
        XCTAssertEqual(snapshot.chartRecords[calendar.startOfDay(for: completionDate)], 2)
    }

    func testSubGoalProgressCountsCompletedGoalsAndAccumulatesSameDayCompletions() {
        let updatedAt = date(year: 2026, month: 4, day: 20, hour: 12)
        let snapshot = GoalProgressCalculator.snapshot(
            goalId: 10,
            tracking: tracking(type: .sub_goal),
            tasks: [],
            subGoals: [
                goal(id: 11, isCompleted: true, parentId: 10, updatedAt: updatedAt),
                goal(id: 12, isCompleted: true, parentId: 10, updatedAt: updatedAt),
                goal(id: 13, isCompleted: false, parentId: 10, updatedAt: updatedAt)
            ],
            calendar: calendar
        )

        XCTAssertEqual(snapshot.current, 2)
        XCTAssertEqual(snapshot.target, 3)
        XCTAssertEqual(snapshot.label, "Goals")
        XCTAssertEqual(snapshot.chartRecords[calendar.startOfDay(for: updatedAt)], 2)
    }

    func testZeroTargetReturnsZeroPercentage() {
        let snapshot = GoalProgressCalculator.snapshot(
            goalId: 10,
            tracking: customTracking(target: 0, label: "Hours"),
            tasks: [],
            subGoals: [],
            customRecords: [
                customRecord(id: 1, value: 1, createdAt: date(year: 2026, month: 4, day: 20), label: "Hours")
            ],
            calendar: calendar
        )

        XCTAssertEqual(snapshot.percentage, 0)
    }

    func testOverTargetProgressClampsPercentageToOne() {
        let snapshot = GoalProgressCalculator.snapshot(
            goalId: 10,
            tracking: customTracking(target: 2, label: "Hours"),
            tasks: [],
            subGoals: [],
            customRecords: [
                customRecord(id: 1, value: 3, createdAt: date(year: 2026, month: 4, day: 20), label: "Hours")
            ],
            calendar: calendar
        )

        XCTAssertEqual(snapshot.percentage, 1)
    }

    func testNilOrUnknownTrackingReturnsEmptySnapshot() {
        XCTAssertEqual(
            GoalProgressCalculator.snapshot(goalId: 10, tracking: nil, tasks: [], subGoals: [], calendar: calendar),
            .empty
        )

        XCTAssertEqual(
            GoalProgressCalculator.snapshot(goalId: 10, tracking: tracking(type: .unknown), tasks: [], subGoals: [], calendar: calendar),
            .empty
        )
    }

    private func tracking(type: GoalTrackingType) -> GoalsTracking {
        GoalsTracking(
            id: 1,
            goal_id: 10,
            type: type,
            value: nil,
            target: nil,
            label: nil,
            created_at: nil,
            updated_at: nil
        )
    }

    private func customTracking(target: Double, label: String?) -> GoalsTracking {
        GoalsTracking(
            id: 1,
            goal_id: 10,
            type: .custom,
            value: nil,
            target: target,
            label: label,
            created_at: nil,
            updated_at: nil
        )
    }

    private func customRecord(id: Int64, value: Double, createdAt: Date, label: String) -> GoalsTrackingRecord {
        GoalsTrackingRecord(
            id: id,
            goals_tracking_id: 1,
            type: .custom,
            value: value,
            label: label,
            created_at: createdAt
        )
    }

    private func task(id: Int64, isCompleted: Bool, completedAt: Date?) -> Tasks {
        Tasks(
            id: id,
            title: "Task \(id)",
            description: nil,
            priority: 1,
            goal_id: 10,
            lifearea_id: nil,
            is_completed: isCompleted,
            is_deadline: false,
            completed_at: completedAt,
            recursion_rule: nil,
            start_date: nil,
            duration: nil,
            created_at: nil,
            updated_at: completedAt
        )
    }

    private func goal(id: Int64, isCompleted: Bool, parentId: Int64, updatedAt: Date) -> Goals {
        Goals(
            id: id,
            title: "Goal \(id)",
            lifearea_id: 1,
            start_date: nil,
            deadline: nil,
            color: nil,
            description: nil,
            icon: "target",
            is_completed: isCompleted,
            parent_id: parentId,
            updated_at: updatedAt
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
