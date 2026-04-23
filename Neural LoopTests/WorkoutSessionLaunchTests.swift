import XCTest
@testable import Neural_Loop

@MainActor
final class WorkoutSessionLaunchTests: XCTestCase {
    
    func testLaunchSessionCreatesWorkoutSessionAndExerciseStates() async throws {
        let routineID: Int64 = 1
        let routine = Routine(id: routineID, name: "Test Routine", notes: "Some notes")
        let exercises = [
            Exercise(id: 10, name: "Exercise 1", type: .repBased, equipment_id: 100, notes: nil),
            Exercise(id: 11, name: "Exercise 2", type: .repBased, equipment_id: 101, notes: nil)
        ]
        let equipment = [
            Equipment(id: 100, name: "Dumbbell"),
            Equipment(id: 101, name: "Barbell")
        ]
        let routineExercises = [
            RoutineExercise(id: 1000, routine_id: routineID, exercise_id: 10, order_index: 0, target_sets: 3, target_reps: 10, rest_seconds: 60, superset_group_id: nil, duration: nil),
            RoutineExercise(id: 1001, routine_id: routineID, exercise_id: 11, order_index: 1, target_sets: 4, target_reps: 8, rest_seconds: 90, superset_group_id: nil, duration: nil)
        ]
        
        let db = FakeLaunchDataManager()
        db.stubRoutine = routine
        db.stubExercises = exercises
        db.stubEquipment = equipment
        db.stubRoutineExercises = routineExercises
        
        let coordinator = WorkoutSessionLaunchCoordinator(db: db)
        
        let (session, states) = try await coordinator.launchSession(for: routineID)
        
        let sessionType = session.session_type
        let sessionNotes = session.notes
        XCTAssertEqual(sessionType, "Test Routine")
        XCTAssertEqual(sessionNotes, "Some notes")
        XCTAssertEqual(states.count, 2)
        
        let name0 = states[0].exercise.name
        let equip0 = states[0].exercise.equipmentName
        let sets0 = states[0].sets.count
        let reps0 = states[0].sets[0].repsText
        XCTAssertEqual(name0, "Exercise 1")
        XCTAssertEqual(equip0, "Dumbbell")
        XCTAssertEqual(sets0, 3)
        XCTAssertEqual(reps0, "10")
        
        let name1 = states[1].exercise.name
        let equip1 = states[1].exercise.equipmentName
        let sets1 = states[1].sets.count
        let reps1 = states[1].sets[0].repsText
        XCTAssertEqual(name1, "Exercise 2")
        XCTAssertEqual(equip1, "Barbell")
        XCTAssertEqual(sets1, 4)
        XCTAssertEqual(reps1, "8")
        
        let capturedType = db.capturedCreateSessionRequest?.session_type
        XCTAssertEqual(capturedType, "Test Routine")
    }
    
    func testLaunchSessionThrowsRoutineNotFoundIfRoutineMissing() async {
        let db = FakeLaunchDataManager()
        db.stubRoutine = nil
        
        let coordinator = WorkoutSessionLaunchCoordinator(db: db)
        
        do {
            _ = try await coordinator.launchSession(for: 1)
            XCTFail("Should have thrown routineNotFound")
        } catch let error as WorkoutLaunchError {
            XCTAssertEqual(error, .routineNotFound)
        } catch {
            XCTFail("Wrong error thrown: \(error)")
        }
    }
    
    func testLaunchSessionPreventsDoubleLaunch() async throws {
        let routineID: Int64 = 1
        let db = FakeLaunchDataManager()
        db.stubRoutine = Routine(id: routineID, name: "Test", notes: nil)
        // Make fetchRoutineExercises slow to trigger re-entrancy
        db.fetchRoutineExercisesDelay = 0.1
        
        let coordinator = WorkoutSessionLaunchCoordinator(db: db)
        
        let expectation1 = expectation(description: "First launch finishes")
        let expectation2 = expectation(description: "Second launch throws")
        
        Task {
            do {
                _ = try await coordinator.launchSession(for: routineID)
                expectation1.fulfill()
            } catch {
                XCTFail("First launch should succeed but failed with \(error)")
            }
        }
        
        // Wait a bit to ensure the first task has started and is suspended at an await
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        Task {
            do {
                _ = try await coordinator.launchSession(for: routineID)
                XCTFail("Second launch should have failed")
            } catch let error as WorkoutLaunchError {
                XCTAssertEqual(error, .launchInProgress)
                expectation2.fulfill()
            } catch {
                XCTFail("Wrong error thrown: \(error)")
            }
        }
        
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
    }
}

class FakeLaunchDataManager: WorkoutTemplateReadingDataManaging, WorkoutDataManaging {
    var stubRoutine: Routine?
    var stubExercises: [Exercise] = []
    var stubEquipment: [Equipment] = []
    var stubRoutineExercises: [RoutineExercise] = []
    var fetchRoutineExercisesDelay: TimeInterval = 0
    
    var capturedCreateSessionRequest: CreateWorkoutSessionRequest?
    
    func fetchRoutine(by id: Int64) async throws -> Routine? {
        stubRoutine
    }
    
    func fetchAllRoutines() async throws -> [Routine] {
        stubRoutine.map { [$0] } ?? []
    }
    
    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        if fetchRoutineExercisesDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchRoutineExercisesDelay * 1_000_000_000))
        }
        return stubRoutineExercises
    }
    
    func fetchAllExercises() async throws -> [Exercise] {
        stubExercises
    }
    
    func fetchAllEquipment() async throws -> [Equipment] {
        stubEquipment
    }
    
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        capturedCreateSessionRequest = request
        return WorkoutSession(
            id: 123,
            date: request.date ?? Date(),
            start_time: request.start_time,
            end_time: request.end_time,
            session_type: request.session_type,
            notes: request.notes
        )
    }
    
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        fatalError("Not implemented")
    }
    
    func deleteWorkoutSession(id: Int64) async throws {}
}
