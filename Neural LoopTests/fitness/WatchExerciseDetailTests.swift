import XCTest
import Combine
@testable import Neural_Loop

@MainActor
final class WatchExerciseDetailTests: XCTestCase {
    var store: WatchWorkoutStore!
    var mockConnectivity: StoreMockConnectivityManager!
    let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot.test"
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
        mockConnectivity = StoreMockConnectivityManager()
        store = WatchWorkoutStore(connectivityManager: mockConnectivity)
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        store = nil
        mockConnectivity = nil
        super.tearDown()
    }
    
    func testAddSetActionDispatch() {
        // Given
        let exerciseID = "e1"
        store.currentSnapshot = createSampleSnapshot(withExercises: [
            ExerciseSnapshot(id: exerciseID, name: "Squat", orderIndex: 0, sets: [])
        ])
        
        // When
        store.addSet(exerciseID: exerciseID)
        
        // Then
        let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
        XCTAssertEqual(exercise?.sets.count, 1)
        XCTAssertEqual(exercise?.sets.first?.setNumber, 1)
        
        if case .addSet(let reference) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(reference.exerciseID, exerciseID)
        } else {
            XCTFail("Expected addSet action to be sent")
        }
    }
    
    func testDoneExerciseActionDispatch() {
        // Given
        let exerciseID = "e1"
        store.currentSnapshot = createSampleSnapshot(withExercises: [
            ExerciseSnapshot(id: exerciseID, name: "Squat", orderIndex: 0, sets: [
                SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: false)
            ])
        ])
        
        // When
        store.toggleExerciseCompletion(exerciseID: exerciseID, isCompleted: true)
        
        // Then
        let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
        XCTAssertTrue(exercise?.isCompleted ?? false)
        XCTAssertTrue(exercise?.sets.first?.isCompleted ?? false, "All sets should be marked completed when exercise is done")
        
        if case .updateExerciseCompletion(let action) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(action.reference.exerciseID, exerciseID)
            XCTAssertTrue(action.isCompleted)
        } else {
            XCTFail("Expected updateExerciseCompletion action to be sent")
        }
    }
    
    func testCompletedSetDisplayLogic() {
        // Given
        let exerciseID = "e1"
        store.currentSnapshot = createSampleSnapshot(withExercises: [
            ExerciseSnapshot(id: exerciseID, name: "Squat", orderIndex: 0, sets: [
                SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: false)
            ])
        ])
        
        // When
        store.toggleSetCompletion(exerciseID: exerciseID, setID: "s1", isCompleted: true)
        
        // Then
        let set = store.currentSnapshot?.exercises.first?.sets.first
        XCTAssertTrue(set?.isCompleted ?? false)
    }
    
    func testSetEntryUpdatesStore() {
        // Given
        let exerciseID = "e1"
        let setID = "s1"
        store.currentSnapshot = createSampleSnapshot(withExercises: [
            ExerciseSnapshot(id: exerciseID, name: "Squat", orderIndex: 0, sets: [
                SetSnapshot(id: setID, setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: false)
            ])
        ])
        
        // When
        store.updateSetValues(exerciseID: exerciseID, setID: setID, kg: 100.5, reps: 5)
        
        // Then
        let set = store.currentSnapshot?.exercises.first?.sets.first
        XCTAssertEqual(set?.values.kg, 100.5)
        XCTAssertEqual(set?.values.reps, 5)
        
        if case .updateSetValues(let action) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(action.reference.exerciseID, exerciseID)
            XCTAssertEqual(action.reference.setID, setID)
            XCTAssertEqual(action.values.kg, 100.5)
            XCTAssertEqual(action.values.reps, 5)
        } else {
            XCTFail("Expected updateSetValues action to be sent")
        }
    }
    
    func testEmptySetListBehavior() {
        // Given
        let exerciseID = "e1"
        store.currentSnapshot = createSampleSnapshot(withExercises: [
            ExerciseSnapshot(id: exerciseID, name: "Squat", orderIndex: 0, sets: [])
        ])
        
        // Then
        let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
        XCTAssertNotNil(exercise)
        XCTAssertTrue(exercise?.sets.isEmpty ?? false)
    }

    func testDisabledStatesAfterExerciseCompletion() {
        // Given
        let exerciseID = "e1"
        store.currentSnapshot = createSampleSnapshot(withExercises: [
            ExerciseSnapshot(id: exerciseID, name: "Squat", orderIndex: 0, isCompleted: true, sets: [
                SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true)
            ])
        ])
        
        // Then
        let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
        XCTAssertTrue(exercise?.isCompleted ?? false)
        // In the view, this would disable Add Set button and navigation links.
        // From store perspective, we can still call these but they might be logically incorrect
        // to call from the UI. The test confirms the state is correct for the view to use.
    }

    private func createSampleSnapshot(withExercises exercises: [ExerciseSnapshot]) -> ActiveWorkoutSnapshot {
        let session = WorkoutSessionPointer(id: "test-session", routineID: 1, workoutSessionID: 1)
        return ActiveWorkoutSnapshot(
            session: session,
            title: "Test Workout",
            startedAt: Date(),
            elapsedSeconds: 0,
            exercises: exercises
        )
    }
}
