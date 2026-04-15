import XCTest
@testable import Neural_Loop

@MainActor
final class ContentViewNavigationTests: XCTestCase {
    func testTasksTabRoutesToMergedShellDestination() {
        XCTAssertEqual(AppTab.tasks.shellDestination, .tasks)
        XCTAssertEqual(AppTab.tasks.rawValue, "Tasks")
        XCTAssertEqual(AppTab.tasks.systemImage, "checklist")
    }

    func testNotesTabRoutesToNotesShellDestination() {
        XCTAssertEqual(AppTab.notes.shellDestination, .notes)
        XCTAssertEqual(AppTab.notes.rawValue, "Notes")
        XCTAssertEqual(AppTab.notes.systemImage, "note.text")
    }

    func testPrimaryTabsContainMergedTasksDestination() {
        XCTAssertEqual(AppTab.allCases.count, 5)
        XCTAssertTrue(AppTab.allCases.contains(.tasks))
        XCTAssertTrue(AppTab.allCases.contains(.notes))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "To do" }))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "Habits" }))
    }
}
