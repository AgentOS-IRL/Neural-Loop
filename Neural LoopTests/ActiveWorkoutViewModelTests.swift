import XCTest
@testable import Neural_Loop

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
    
    func testFinishWorkoutSavesSessionAndSetsWithValidReps() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 10, name: "E1", type: .repBased, equipmentID: nil, equipmentName: "None")
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, weightText: "100", repsText: "10"),
            WorkoutSetDraft(setNumber: 2, weightText: "100", repsText: "0"), // Should be ignored
            WorkoutSetDraft(setNumber: 3, weightText: "110", repsText: "8")
        ])
        
        let viewModel = ActiveWorkoutViewModel(session: session, exerciseStates: [state], db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertNotNil(db.capturedSessionRequest)
        XCTAssertEqual(db.capturedSessionRequest?.session_type, "Test")
        XCTAssertEqual(db.capturedSetRequests.count, 2)
        
        XCTAssertEqual(db.capturedSetRequests[0].exercise_id, 10)
        XCTAssertEqual(db.capturedSetRequests[0].reps, 10)
        XCTAssertEqual(db.capturedSetRequests[0].weight, 100)
        
        XCTAssertEqual(db.capturedSetRequests[1].reps, 8)
        XCTAssertEqual(db.capturedSetRequests[1].weight, 110)
        
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpdateDurationUpdatesState() async {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        let exercise = ExerciseLibraryItem(id: 1, name: "E1", type: .duration, equipmentID: nil, equipmentName: "None")
        let set = WorkoutSetDraft(setNumber: 1)
        let state = WorkoutExerciseCardState(id: 1, exercise: exercise, sets: [set])
        let viewModel = ActiveWorkoutViewModel(session: session, exerciseStates: [state], db: db)

        viewModel.updateDuration(for: 1, setID: set.id, durationText: "15.5")

        XCTAssertEqual(viewModel.exerciseStates[0].sets[0].durationText, "15.5")
    }

    func testFinishWorkoutSavesCardioLogs() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 20, name: "Running", type: .duration, equipmentID: nil, equipmentName: "None")
        let state = WorkoutExerciseCardState(id: 2, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, durationText: "30"),
            WorkoutSetDraft(setNumber: 2, durationText: "0"), // Should be ignored
            WorkoutSetDraft(setNumber: 3, durationText: "45")
        ])
        
        let viewModel = ActiveWorkoutViewModel(session: session, exerciseStates: [state], db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertEqual(db.capturedCardioRequests.count, 2)
        XCTAssertEqual(db.capturedCardioRequests[0].exercise_id, 20)
        XCTAssertEqual(db.capturedCardioRequests[0].duration_minutes, 30)
        XCTAssertEqual(db.capturedCardioRequests[1].duration_minutes, 45)
    }

    func testFinishWorkoutSavesCardioLogsWithDecimalDuration() async throws {
        let db = FakeWorkoutDataManager()
        let session = WorkoutSession(id: nil, date: Date(), start_time: "2026-04-23T10:00:00Z", end_time: nil, session_type: "Test", notes: "Notes")
        let exercise = ExerciseLibraryItem(id: 20, name: "Running", type: .duration, equipmentID: nil, equipmentName: "None")
        
        // Testing decimal duration
        let state = WorkoutExerciseCardState(id: 2, exercise: exercise, sets: [
            WorkoutSetDraft(setNumber: 1, durationText: "15.5")
        ])
        
        let viewModel = ActiveWorkoutViewModel(session: session, exerciseStates: [state], db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertEqual(db.capturedCardioRequests.count, 1)
        XCTAssertEqual(db.capturedCardioRequests[0].duration_minutes, 15.5)
    }
    
    func testFinishWorkoutSetsErrorMessageOnFailure() async {
        let db = FakeWorkoutDataManager()
        db.shouldFail = true
        let session = WorkoutSession(id: nil, date: Date(), start_time: nil, end_time: nil, session_type: "Test", notes: nil)
        
        let viewModel = ActiveWorkoutViewModel(session: session, exerciseStates: [], db: db)
        
        await viewModel.finishWorkout()
        
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

class FakeWorkoutDataManager: WorkoutDataManaging {
    var shouldFail = false
    var capturedSessionRequest: CreateWorkoutSessionRequest?
    var capturedSetRequests: [CreateWorkoutSetRequest] = []
    var capturedCardioRequests: [CreateCardioLogRequest] = []
    
    func fetchAllEquipment() async throws -> [Equipment] { [] }
    func fetchAllExercises() async throws -> [Exercise] { [] }
    
    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        capturedSessionRequest = request
        return WorkoutSession(id: 123, date: request.date ?? Date(), start_time: request.start_time, end_time: request.end_time, session_type: request.session_type, notes: request.notes)
    }
    
    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        capturedSetRequests.append(request)
        return WorkoutSet(id: Int64(capturedSetRequests.count), workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, set_number: request.set_number, reps: request.reps, weight: request.weight, superset_group_id: request.superset_group_id)
    }

    func createCardioLog(_ request: CreateCardioLogRequest) async throws -> CardioLog {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        capturedCardioRequests.append(request)
        return CardioLog(id: Int64(capturedCardioRequests.count), workout_session_id: request.workout_session_id, exercise_id: request.exercise_id, distance_meters: request.distance_meters, duration_minutes: request.duration_minutes, calories: request.calories)
    }
    
    func deleteWorkoutSession(id: Int64) async throws {}
    
    func fetchWorkoutSets(exerciseId: Int64) async throws -> [WorkoutSet] {
        return []
    }
}
