import XCTest
@testable import Neural_Loop

final class WorkoutExerciseCardStateTests: XCTestCase {
    
    func testColumnHeadersForRepBasedExercise() {
        let exercise = ExerciseLibraryItem(
            id: 1,
            name: "Bench Press",
            type: .repBased,
            equipmentID: 1,
            equipmentName: "Barbell"
        )
        let state = WorkoutExerciseCardState(
            id: 1,
            exercise: exercise,
            sets: []
        )
        
        XCTAssertEqual(state.columnHeaders, ["SET", "KG", "REPS"])
    }
    
    func testColumnHeadersForDurationExercise() {
        let exercise = ExerciseLibraryItem(
            id: 2,
            name: "Running",
            type: .duration,
            equipmentID: nil,
            equipmentName: "None"
        )
        let state = WorkoutExerciseCardState(
            id: 1,
            exercise: exercise,
            sets: []
        )
        
        XCTAssertEqual(state.columnHeaders, ["SET", "MIN", "KM", "KCAL"])
    }
    
    func testAccessibilityLabels() {
        let set = WorkoutSetDraft(setNumber: 1)
        let exerciseName = "Squat"
        
        XCTAssertEqual(set.weightAccessibilityLabel(exerciseName: exerciseName), "Squat set 1 kilograms")
        XCTAssertEqual(set.repsAccessibilityLabel(exerciseName: exerciseName), "Squat set 1 reps")
        XCTAssertEqual(set.durationAccessibilityLabel(exerciseName: exerciseName), "Squat set 1 duration")
        XCTAssertEqual(set.distanceAccessibilityLabel(exerciseName: exerciseName), "Squat set 1 distance")
        XCTAssertEqual(set.caloriesAccessibilityLabel(exerciseName: exerciseName), "Squat set 1 calories")
    }
}
