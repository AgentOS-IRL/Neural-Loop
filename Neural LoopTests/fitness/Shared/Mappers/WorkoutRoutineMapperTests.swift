import XCTest
@testable import Neural_Loop

final class WorkoutRoutineMapperTests: XCTestCase {
    
    func testMappingPreservesOrder() {
        // Given
        let routine = Routine(id: 1, name: "Test Routine", notes: "Notes")
        let routineExercises = [
            RoutineExercise(id: 10, routine_id: 1, exercise_id: 100, order_index: 2),
            RoutineExercise(id: 11, routine_id: 1, exercise_id: 101, order_index: 1),
            RoutineExercise(id: 12, routine_id: 1, exercise_id: 102, order_index: 3)
        ]
        let allExercises = [
            Exercise(id: 100, name: "Ex 100", type: .repBased, equipment_id: 1),
            Exercise(id: 101, name: "Ex 101", type: .repBased, equipment_id: 1),
            Exercise(id: 102, name: "Ex 102", type: .repBased, equipment_id: 1)
        ]
        let allEquipment = [Equipment(id: 1, name: "Barbell")]
        
        // When
        let state = WorkoutRoutineMapper.mapToSessionState(
            routine: routine,
            routineExercises: routineExercises,
            allExercises: allExercises,
            allEquipment: allEquipment
        )
        
        // Then
        XCTAssertEqual(state.exercises.count, 3)
        XCTAssertEqual(state.exercises[0].exercise.id, 101)
        XCTAssertEqual(state.exercises[1].exercise.id, 100)
        XCTAssertEqual(state.exercises[2].exercise.id, 102)
    }
    
    func testMetadataCarriedOver() {
        // Given
        let routine = Routine(id: 1, name: "Test Routine")
        let routineExercises = [
            RoutineExercise(
                id: 10,
                routine_id: 1,
                exercise_id: 100,
                order_index: 1,
                target_sets: 3,
                target_reps: 10,
                rest_seconds: 60,
                duration: Decimal(30)
            )
        ]
        let allExercises = [Exercise(id: 100, name: "Ex 100", type: .repBased, equipment_id: 1)]
        let allEquipment = [Equipment(id: 1, name: "Barbell")]
        
        // When
        let state = WorkoutRoutineMapper.mapToSessionState(
            routine: routine,
            routineExercises: routineExercises,
            allExercises: allExercises,
            allEquipment: allEquipment
        )
        
        // Then
        let exerciseState = state.exercises[0]
        XCTAssertEqual(exerciseState.targetSets, 3)
        XCTAssertEqual(exerciseState.targetReps, 10)
        XCTAssertEqual(exerciseState.restSeconds, 60)
        XCTAssertEqual(exerciseState.targetDuration, Decimal(30))
        
        XCTAssertEqual(exerciseState.sets.count, 3)
        XCTAssertEqual(exerciseState.sets[0].repsText, "10")
    }
    
    func testRepBasedVsCardioMapping() {
        // Given
        let routine = Routine(id: 1, name: "Test Routine")
        let routineExercises = [
            RoutineExercise(id: 10, routine_id: 1, exercise_id: 100, order_index: 1, target_sets: 3, target_reps: 10),
            RoutineExercise(id: 11, routine_id: 1, exercise_id: 101, order_index: 2, target_sets: 1, duration: Decimal(20))
        ]
        let allExercises = [
            Exercise(id: 100, name: "Rep Based", type: .repBased, equipment_id: 1),
            Exercise(id: 101, name: "Cardio", type: .duration, equipment_id: nil)
        ]
        let allEquipment = [Equipment(id: 1, name: "Barbell")]
        
        // When
        let state = WorkoutRoutineMapper.mapToSessionState(
            routine: routine,
            routineExercises: routineExercises,
            allExercises: allExercises,
            allEquipment: allEquipment
        )
        
        // Then
        XCTAssertEqual(state.exercises[0].exercise.type, .repBased)
        XCTAssertEqual(state.exercises[0].sets[0].repsText, "10")
        
        XCTAssertEqual(state.exercises[1].exercise.type, .duration)
        XCTAssertEqual(state.exercises[1].targetDuration, Decimal(20))
        XCTAssertEqual(state.exercises[1].sets[0].durationText, "20")
    }
    
    func testMissingOptionalValues() {
        // Given
        let routine = Routine(id: 1, name: "Test Routine")
        let routineExercises = [
            RoutineExercise(id: 10, routine_id: 1, exercise_id: 100, order_index: 1, target_sets: nil, target_reps: nil)
        ]
        let allExercises = [Exercise(id: 100, name: "Ex 100", type: .repBased, equipment_id: nil)]
        let allEquipment: [Equipment] = []
        
        // When
        let state = WorkoutRoutineMapper.mapToSessionState(
            routine: routine,
            routineExercises: routineExercises,
            allExercises: allExercises,
            allEquipment: allEquipment
        )
        
        // Then
        let exerciseState = state.exercises[0]
        XCTAssertNil(exerciseState.targetSets)
        XCTAssertNil(exerciseState.targetReps)
        XCTAssertEqual(exerciseState.sets.count, 1) // Defaulted to 1 set in mapper logic: max(1, re.target_sets ?? 1)
        XCTAssertEqual(exerciseState.sets[0].repsText, "")
    }
    
    func testCodableRoundTrip() throws {
        // Given
        let session = WorkoutSession(id: 5, date: Date(), start_time: "10:00", end_time: nil, session_type: "Test", notes: "Notes")
        let exercises = [
            WorkoutExerciseCardState(
                id: 1,
                exercise: ExerciseLibraryItem(id: 100, name: "Ex", type: .repBased, equipmentID: 1, equipmentName: "Eq"),
                sets: [WorkoutSetDraft(setNumber: 1, weightText: "100", repsText: "10")],
                targetSets: 3,
                targetReps: 10,
                restSeconds: 60,
                targetDuration: nil
            )
        ]
        let originalState = WorkoutSessionState(session: session, exercises: exercises)
        
        // When
        let data = try JSONEncoder().encode(originalState)
        let decodedState = try JSONDecoder().decode(WorkoutSessionState.self, from: data)
        
        // Then
        XCTAssertEqual(originalState.exercises.count, decodedState.exercises.count)
        XCTAssertEqual(originalState.exercises[0].exercise.name, decodedState.exercises[0].exercise.name)
        XCTAssertEqual(originalState.session.id, decodedState.session.id)
        XCTAssertEqual(originalState.session.session_type, decodedState.session.session_type)
        
        // Check date equality (ignoring sub-second precision if any, though WorkoutSession uses a custom coder)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: originalState.session.date),
            Calendar.current.startOfDay(for: decodedState.session.date)
        )
    }
}
