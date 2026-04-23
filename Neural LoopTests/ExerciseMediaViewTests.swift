import XCTest
@testable import Neural_Loop

final class ExerciseMediaViewTests: XCTestCase {
    func testExerciseMediaDisplayModeSizingContract() {
        XCTAssertEqual(ExerciseMediaDisplayMode.thumbnail.tileSize, CGSize(width: 58, height: 58))
        XCTAssertEqual(ExerciseMediaDisplayMode.hero.tileSize, CGSize(width: 100, height: 72))
        XCTAssertNotEqual(ExerciseMediaDisplayMode.thumbnail.tileSize, ExerciseMediaDisplayMode.hero.tileSize)
        XCTAssertLessThan(ExerciseMediaDisplayMode.thumbnail.tileSize.width, ExerciseMediaDisplayMode.hero.tileSize.width)
        XCTAssertLessThan(ExerciseMediaDisplayMode.thumbnail.tileSize.height, ExerciseMediaDisplayMode.hero.tileSize.height)
    }
}
