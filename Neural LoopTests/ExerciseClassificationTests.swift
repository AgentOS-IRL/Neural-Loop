import XCTest
@testable import Neural_Loop

final class ExerciseClassificationTests: XCTestCase {
    func testExerciseTypeClassification() {
        XCTAssertTrue(ExerciseType.repBased.isRepBased)
        XCTAssertFalse(ExerciseType.repBased.isDurationBased)
        
        XCTAssertTrue(ExerciseType.duration.isDurationBased)
        XCTAssertFalse(ExerciseType.duration.isRepBased)
    }
    
    func testExerciseDelegation() {
        let repExercise = Exercise(id: 1, name: "Squat", type: .repBased, equipment_id: nil, notes: nil)
        XCTAssertTrue(repExercise.isRepBased)
        XCTAssertFalse(repExercise.isDurationBased)
        
        let durationExercise = Exercise(id: 2, name: "Running", type: .duration, equipment_id: nil, notes: nil)
        XCTAssertTrue(durationExercise.isDurationBased)
        XCTAssertFalse(durationExercise.isRepBased)
    }
    
    func testExerciseLibraryItemDelegation() {
        let repItem = ExerciseLibraryItem(id: 1, name: "Squat", type: .repBased, equipmentID: nil, equipmentName: "None")
        XCTAssertTrue(repItem.isRepBased)
        XCTAssertFalse(repItem.isDurationBased)
        
        let durationItem = ExerciseLibraryItem(id: 2, name: "Running", type: .duration, equipmentID: nil, equipmentName: "None")
        XCTAssertTrue(durationItem.isDurationBased)
        XCTAssertFalse(durationItem.isRepBased)
    }
}
