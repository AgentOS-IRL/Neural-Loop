import XCTest
@testable import Neural_Loop

final class WatchExerciseListViewTests: XCTestCase {
    
    func testExerciseSnapshot_CompletedSetsCount() {
        // Given
        let sets = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(), isCompleted: false),
            SetSnapshot(id: "s3", setNumber: 3, values: WorkoutSetValuesSnapshot(), isCompleted: true)
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "Test Exercise", orderIndex: 0, sets: sets)
        
        // Then
        XCTAssertEqual(exercise.completedSetsCount, 2, "Should correctly count completed sets")
    }
    
    func testExerciseSnapshot_EmptySets() {
        // Given
        let exercise = ExerciseSnapshot(id: "e1", name: "Empty Sets Exercise", orderIndex: 0, sets: [])
        
        // Then
        XCTAssertEqual(exercise.completedSetsCount, 0, "Should return 0 for empty sets")
    }
    
    func testExerciseSnapshot_AllCompleted() {
        // Given
        let sets = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(), isCompleted: true)
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "Completed Exercise", orderIndex: 0, sets: sets)
        
        // Then
        XCTAssertEqual(exercise.completedSetsCount, 2, "Should return total count when all sets are completed")
    }

    func testActiveWorkoutSnapshot_EmptyExercises() {
        // Given
        let snapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "session-1"),
            title: "Empty Workout",
            exercises: []
        )
        
        // Then
        XCTAssertTrue(snapshot.exercises.isEmpty, "Snapshot should handle empty exercises list")
    }
    
    func testStableNavigationIDs() {
        // Given
        let id = "fixed-id-123"
        let exercise = ExerciseSnapshot(id: id, name: "Stable ID Exercise", orderIndex: 0)
        
        // Then
        XCTAssertEqual(exercise.id, id, "Exercise ID must be stable and match the initialized value")
    }
    
    func testExerciseCompletionState() {
        // Given
        let completedExercise = ExerciseSnapshot(id: "e1", name: "Done", orderIndex: 0, isCompleted: true)
        let pendingExercise = ExerciseSnapshot(id: "e2", name: "Pending", orderIndex: 1, isCompleted: false)
        
        // Then
        XCTAssertTrue(completedExercise.isCompleted)
        XCTAssertFalse(pendingExercise.isCompleted)
    }
}
