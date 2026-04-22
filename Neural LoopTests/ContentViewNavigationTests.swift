import XCTest
@testable import Neural_Loop

@MainActor
final class ContentViewNavigationTests: XCTestCase {
    func testLoopTabRoutesToMergedShellDestination() {
        XCTAssertEqual(AppTab.tasks.shellDestination, .tasks)
        XCTAssertEqual(AppTab.tasks.rawValue, "Loop")
        XCTAssertEqual(AppTab.tasks.systemImage, "square.grid.2x2")
    }

    func testPrimaryTabsContainMergedTasksDestination() {
        XCTAssertEqual(AppTab.allCases.count, 4)
        XCTAssertTrue(AppTab.allCases.contains(.tasks))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "Notes" }))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "To do" }))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "Habits" }))
    }
}
