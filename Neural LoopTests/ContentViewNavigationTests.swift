import XCTest
@testable import Neural_Loop

@MainActor
final class ContentViewNavigationTests: XCTestCase {
    func testLoopTabRoutesToMergedShellDestination() {
        XCTAssertEqual(AppTab.tasks.shellDestination, .tasks)
        XCTAssertEqual(AppTab.tasks.rawValue, "Loop")
        XCTAssertEqual(AppTab.tasks.systemImage, "square.grid.2x2")
    }

    func testAITabRoutesToAIDestination() {
        XCTAssertEqual(AppTab.ai.shellDestination, .ai)
        XCTAssertEqual(AppTab.ai.rawValue, "AI")
        XCTAssertEqual(AppTab.ai.systemImage, "sparkles")
    }

    func testPrimaryTabsContainMergedTasksDestination() {
        XCTAssertEqual(AppTab.allCases.count, 6)
        XCTAssertEqual(AppTab.allCases, [.goals, .tasks, .ai, .calendar, .fitness, .settings])
        XCTAssertTrue(AppTab.allCases.contains(.tasks))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "Notes" }))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "To do" }))
        XCTAssertFalse(AppTab.allCases.contains(where: { $0.rawValue == "Habits" }))
    }

    func testContentNavigationTabsExcludeSettings() {
        XCTAssertEqual(AppTab.contentTabs, [.goals, .tasks, .ai, .calendar])
        XCTAssertTrue(AppTab.contentTabs.contains(.tasks))
        XCTAssertFalse(AppTab.contentTabs.contains(.fitness))
        XCTAssertFalse(AppTab.contentTabs.contains(.settings))
    }

    func testFitnessRemainsUtilityDestination() {
        XCTAssertEqual(AppTab.fitness.shellDestination, .fitness)
        XCTAssertEqual(AppTab.fitness.rawValue, "Fitness")
        XCTAssertEqual(AppTab.fitness.systemImage, "figure.strengthtraining.traditional")
    }

    func testSettingsRemainsUtilityDestination() {
        XCTAssertEqual(AppTab.settings.shellDestination, .settings)
        XCTAssertEqual(AppTab.settings.rawValue, "Settings")
        XCTAssertEqual(AppTab.settings.systemImage, "gearshape")
    }
}
