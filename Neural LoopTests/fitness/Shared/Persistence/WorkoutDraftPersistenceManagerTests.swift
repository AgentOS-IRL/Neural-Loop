import XCTest
@testable import Neural_Loop

final class WorkoutDraftPersistenceManagerTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var persistenceManager: WorkoutDraftPersistenceManager!
    private let suiteName = "WorkoutDraftPersistenceManagerTests"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSaveAndLoadSessionPointer() {
        let routineID: Int64 = 123
        let pointer = WorkoutSessionPointer(id: "test-id", routineID: routineID, workoutSessionID: nil)
        
        // We need a draft for loadActiveSessionPointer to return the pointer (stale recovery)
        let draft = createDraft(routineID: routineID)
        persistenceManager.save(draft: draft)
        
        persistenceManager.saveActiveSessionPointer(pointer)
        
        let loaded = persistenceManager.loadActiveSessionPointer()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, "test-id")
        XCTAssertEqual(loaded?.routineID, routineID)
    }

    func testClearSessionPointer() {
        let pointer = WorkoutSessionPointer(id: "test-id", routineID: 123, workoutSessionID: nil)
        persistenceManager.saveActiveSessionPointer(pointer)
        
        persistenceManager.clearActiveSessionPointer()
        
        // Directly check UserDefaults to avoid stale recovery logic in loadActiveSessionPointer
        XCTAssertNil(userDefaults.data(forKey: "active_workout_session_pointer"))
    }

    func testClearRoutineDraftAlsoClearsMatchingSessionPointer() {
        let routineID: Int64 = 123
        let pointer = WorkoutSessionPointer(id: "test-id", routineID: routineID, workoutSessionID: nil)
        persistenceManager.saveActiveSessionPointer(pointer)
        
        persistenceManager.clear(routineID: routineID)
        
        XCTAssertNil(userDefaults.data(forKey: "active_workout_session_pointer"))
    }

    func testClearRoutineDraftDoesNotClearMismatchedSessionPointer() {
        let pointer = WorkoutSessionPointer(id: "test-id", routineID: 456, workoutSessionID: nil)
        persistenceManager.saveActiveSessionPointer(pointer)
        
        persistenceManager.clear(routineID: 123)
        
        XCTAssertNotNil(userDefaults.data(forKey: "active_workout_session_pointer"))
    }

    func testLoadSessionPointerReturnsNilIfDraftIsMissing() {
        let pointer = WorkoutSessionPointer(id: "test-id", routineID: 123, workoutSessionID: nil)
        persistenceManager.saveActiveSessionPointer(pointer)
        
        // No draft saved for routineID 123
        
        let loaded = persistenceManager.loadActiveSessionPointer()
        XCTAssertNil(loaded)
        XCTAssertNil(userDefaults.data(forKey: "active_workout_session_pointer"), "Should have cleared the stale pointer")
    }

    func testLoadSessionPointerReturnsNilIfDraftIsStale() {
        let routineID: Int64 = 123
        let pointer = WorkoutSessionPointer(id: "test-id", routineID: routineID, workoutSessionID: nil)
        persistenceManager.saveActiveSessionPointer(pointer)
        
        // Save a stale draft (older than 24h)
        let staleDate = Date().addingTimeInterval(-25 * 60 * 60)
        let draft = createDraft(routineID: routineID, updatedAt: staleDate)
        persistenceManager.save(draft: draft)
        
        let loaded = persistenceManager.loadActiveSessionPointer()
        XCTAssertNil(loaded)
        XCTAssertNil(userDefaults.data(forKey: "active_workout_session_pointer"), "Should have cleared the stale pointer")
    }

    private func createDraft(routineID: Int64, updatedAt: Date = Date()) -> ActiveWorkoutDraft {
        let session = WorkoutSession(id: nil, date: Date(), start_time: "12:00", end_time: nil, session_type: "Test", notes: nil)
        return ActiveWorkoutDraft(
            routineID: routineID,
            session: session,
            exercises: [],
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}
