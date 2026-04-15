import XCTest
@testable import Neural_Loop

@MainActor
final class ContentViewNavigationTests: XCTestCase {
    func testTasksTabRoutesToMergedShellDestination() {
        XCTAssertEqual(AppTab.tasks.shellDestination, .tasks)
        XCTAssertEqual(AppTab.tasks.rawValue, "Tasks")
        XCTAssertEqual(AppTab.tasks.systemImage, "checklist")
    }

    func testPrimaryTabsContainMergedTasksDestination() {
        XCTAssertEqual(AppTab.allCases.count, 4)
        XCTAssertTrue(AppTab.allCases.contains(.tasks))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "To do" }))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "Habits" }))
    }
}
