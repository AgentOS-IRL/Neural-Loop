import XCTest
@testable import Neural_Loop

@MainActor
final class TaskHubNavigationTests: XCTestCase {
    func testTaskHubDefaultsToTodoSection() {
        let model = TaskHubNavigationModel()

        XCTAssertEqual(model.selectedSection, .todo)
        XCTAssertEqual(TaskHubSection.allCases, [.todo, .habits])
    }

    func testTaskHubSelectionSwitchesBetweenTodoAndHabits() {
        let model = TaskHubNavigationModel()

        model.select(.habits)
        XCTAssertEqual(model.selectedSection, .habits)

        model.select(.todo)
        XCTAssertEqual(model.selectedSection, .todo)
    }
}
