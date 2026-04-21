import XCTest
@testable import Neural_Loop

@MainActor
final class TodoBucketFilteringTests: XCTestCase {
    func testRebuildDateBucketsKeepsCompletedTasksOutOfInbox() {
        let calendar = Calendar.neuralLoopDisplay
        let now = Date()

        let inboxTask = makeTask(
            id: 1,
            title: "Inbox task",
            isCompleted: false,
            startDate: nil
        )
        let completedTaskWithoutStart = makeTask(
            id: 2,
            title: "Completed no start",
            isCompleted: true,
            startDate: nil
        )
        let completedTaskWithStart = makeTask(
            id: 3,
            title: "Completed with start",
            isCompleted: true,
            startDate: calendar.date(byAdding: .day, value: 1, to: now)
        )
        let overdueTask = makeTask(
            id: 4,
            title: "Overdue task",
            isCompleted: false,
            startDate: calendar.date(byAdding: .day, value: -1, to: now)
        )
        let todayTask = makeTask(
            id: 5,
            title: "Today task",
            isCompleted: false,
            startDate: now
        )
        let upcomingTask = makeTask(
            id: 6,
            title: "Upcoming task",
            isCompleted: false,
            startDate: calendar.date(byAdding: .day, value: 1, to: now)
        )

        let buckets = rebuildDateBuckets(tasks: [
            inboxTask,
            completedTaskWithoutStart,
            completedTaskWithStart,
            overdueTask,
            todayTask,
            upcomingTask
        ])

        XCTAssertEqual(taskIDs(in: buckets, type: .inbox), [1])
        XCTAssertEqual(taskIDs(in: buckets, type: .completed), [2, 3])
        XCTAssertEqual(taskIDs(in: buckets, type: .overdue), [4])
        XCTAssertEqual(taskIDs(in: buckets, type: .today), [5])
        XCTAssertTrue(taskIDs(in: buckets, type: .upcoming).contains(6))
        XCTAssertFalse(taskIDs(in: buckets, type: .inbox).contains(2))
        XCTAssertFalse(taskIDs(in: buckets, type: .inbox).contains(3))
    }

    private func makeTask(
        id: Int64,
        title: String,
        isCompleted: Bool,
        startDate: Date?
    ) -> Tasks {
        Tasks(
            id: id,
            title: title,
            description: nil,
            priority: 0,
            goal_id: nil,
            lifearea_id: nil,
            is_completed: isCompleted,
            is_deadline: false,
            completed_at: isCompleted ? Date() : nil,
            recursion_rule: nil,
            start_date: startDate,
            duration: nil,
            created_at: nil,
            updated_at: nil
        )
    }

    private func taskIDs(in buckets: [DateBucket], type: bucketType) -> [Int64] {
        buckets.first(where: { $0.type == type })?.ids ?? []
    }
}
