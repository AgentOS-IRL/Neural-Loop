import XCTest
@testable import Neural_Loop

@MainActor
final class TaskHubNavigationTests: XCTestCase {
    func testTaskHubDefaultsToTodoSection() {
        let model = TaskHubNavigationModel()

        XCTAssertEqual(model.selectedSection, .todo)
        XCTAssertEqual(TaskHubSection.allCases, [.todo, .habits, .notes])
    }

    func testTaskHubSelectionSwitchesBetweenSections() {
        let model = TaskHubNavigationModel()

        model.select(.habits)
        XCTAssertEqual(model.selectedSection, .habits)

        model.select(.notes)
        XCTAssertEqual(model.selectedSection, .notes)

        model.select(.todo)
        XCTAssertEqual(model.selectedSection, .todo)
    }

    func testTaskHubLeftSwipeMovesFromTodoToHabits() {
        let model = TaskHubNavigationModel()

        XCTAssertEqual(model.selectedSection, .todo)

        model.handleSwipe(.left)

        XCTAssertEqual(model.selectedSection, .habits)
    }

    func testTaskHubLeftSwipeMovesFromHabitsToNotes() {
        let model = TaskHubNavigationModel()

        model.select(.habits)
        model.handleSwipe(.left)

        XCTAssertEqual(model.selectedSection, .notes)
    }

    func testTaskHubLeftSwipeStaysOnNotes() {
        let model = TaskHubNavigationModel()

        model.select(.notes)
        model.handleSwipe(.left)

        XCTAssertEqual(model.selectedSection, .notes)
    }

    func testTaskHubRightSwipeMovesFromHabitsToTodo() {
        let model = TaskHubNavigationModel()

        model.select(.habits)
        model.handleSwipe(.right)

        XCTAssertEqual(model.selectedSection, .todo)
    }

    func testTaskHubRightSwipeMovesFromNotesToHabits() {
        let model = TaskHubNavigationModel()

        model.select(.notes)
        model.handleSwipe(.right)

        XCTAssertEqual(model.selectedSection, .habits)
    }

    func testTaskHubRightSwipeStaysOnTodo() {
        let model = TaskHubNavigationModel()

        model.handleSwipe(.right)

        XCTAssertEqual(model.selectedSection, .todo)
    }

    func testTaskHubSwipeAtBoundsKeepsCurrentSection() {
        let model = TaskHubNavigationModel()

        model.handleSwipe(.right)
        XCTAssertEqual(model.selectedSection, .todo)

        model.select(.notes)
        model.handleSwipe(.left)
        XCTAssertEqual(model.selectedSection, .notes)
    }

    func testTaskHubSectionAfterSwipeDoesNotMutateSelection() {
        let model = TaskHubNavigationModel()

        XCTAssertEqual(model.section(afterSwipe: .left), .habits)
        XCTAssertEqual(model.selectedSection, .todo)

        model.select(.habits)
        XCTAssertEqual(model.section(afterSwipe: .right), .todo)
        XCTAssertEqual(model.selectedSection, .habits)

        XCTAssertEqual(model.section(afterSwipe: .left), .notes)
        XCTAssertEqual(model.selectedSection, .habits)
    }

    func testTodoBackNavigationDoesNothingOnMenu() {
        let model = TodoViewModel()

        model.viewMode = .menu

        XCTAssertFalse(model.canNavigateBackToMenu())
        XCTAssertFalse(model.handleBackSwipeIfNeeded())
        XCTAssertEqual(model.viewMode, .menu)
    }

    func testTodoBackNavigationReturnsSubViewToMenu() {
        let model = TodoViewModel()

        model.viewMode = .today

        XCTAssertTrue(model.canNavigateBackToMenu())
        XCTAssertTrue(model.handleBackSwipeIfNeeded())
        XCTAssertEqual(model.viewMode, .menu)
    }
}
