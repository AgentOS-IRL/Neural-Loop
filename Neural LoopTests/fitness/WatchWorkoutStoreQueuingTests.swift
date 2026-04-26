import XCTest
import Combine
@testable import Neural_Loop

@MainActor
final class WatchWorkoutStoreQueuingTests: XCTestCase {
    var store: WatchWorkoutStore!
    var mockConnectivity: QueuingMockConnectivityManager!
    let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot.test"
    let queueKey = "com.neuralloop.watch.actionQueue.test"
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: queueKey)
        mockConnectivity = QueuingMockConnectivityManager()
        store = WatchWorkoutStore(connectivityManager: mockConnectivity)
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: queueKey)
        store = nil
        mockConnectivity = nil
        super.tearDown()
    }
    
    func testQueuePersistence() {
        // Given: unreachable
        mockConnectivity.isReachable = false
        store.currentSnapshot = createSampleSnapshot()
        
        // When: trigger action
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 60, reps: 8)
        
        // Then: verify queue has 1 item
        XCTAssertEqual(store.getActionQueue().count, 1)
        
        // When: Restart store
        let newStore = WatchWorkoutStore(connectivityManager: mockConnectivity)
        
        // Then: verify queue still has 1 item
        XCTAssertEqual(newStore.getActionQueue().count, 1)
    }
    
    func testFIFOFlushOrder() {
        // Given: unreachable with 3 actions
        mockConnectivity.isReachable = false
        store.currentSnapshot = createSampleSnapshot()
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 10, reps: 1)
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 20, reps: 2)
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 30, reps: 3)
        
        XCTAssertEqual(store.getActionQueue().count, 3)
        
        // When: Become reachable
        mockConnectivity.isReachable = true
        
        // Then: Verify order of sent actions
        let expectation = expectation(description: "Wait for flush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.mockConnectivity.sentActions.count, 3)
            if self.mockConnectivity.sentActions.count == 3 {
                if case .updateSetValues(let a1) = self.mockConnectivity.sentActions[0].payload {
                    XCTAssertEqual(a1.values.kg, 10)
                }
                if case .updateSetValues(let a2) = self.mockConnectivity.sentActions[1].payload {
                    XCTAssertEqual(a2.values.kg, 20)
                }
                if case .updateSetValues(let a3) = self.mockConnectivity.sentActions[2].payload {
                    XCTAssertEqual(a3.values.kg, 30)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testFlushLoopStopsOnFailure() {
        // Given: unreachable with 2 actions
        mockConnectivity.isReachable = false
        store.currentSnapshot = createSampleSnapshot()
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 10, reps: 1)
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 20, reps: 2)
        
        XCTAssertEqual(store.getActionQueue().count, 2)
        
        // When: Become reachable but first action fails
        mockConnectivity.isReachable = true
        mockConnectivity.shouldFail = true
        
        // Then: Verify only 1 action was attempted and queue is not advanced
        let expectation = expectation(description: "Wait for flush attempt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.mockConnectivity.sentActions.count, 1)
            XCTAssertEqual(self.store.getActionQueue().count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAuthoritativeReconciliation() {
        // Given: Local state has queued change
        mockConnectivity.isReachable = false
        var snapshot = createSampleSnapshot()
        snapshot.exercises = [
            ExerciseSnapshot(id: "e1", name: "Ex 1", orderIndex: 0, sets: [
                SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 50, reps: 10))
            ])
        ]
        store.currentSnapshot = snapshot
        
        // Watch queues "Reps = 12"
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 50, reps: 12)
        let actionID = store.getActionQueue().first!.id
        XCTAssertEqual(store.currentSnapshot?.exercises[0].sets[0].values.reps, 12)
        
        // When: Receive snapshot where lastProcessedActionID matches
        var authoritative = snapshot
        authoritative.lastProcessedActionID = actionID
        authoritative.exercises[0].sets[0].values.reps = 12 // iPhone processed it
        
        mockConnectivity.lastSnapshot = authoritative
        
        // Then: Verify queue is cleared
        let expectation = expectation(description: "Wait for reconcile")
        DispatchQueue.main.async {
            XCTAssertEqual(self.store.getActionQueue().count, 0)
            XCTAssertEqual(self.store.currentSnapshot?.exercises[0].sets[0].values.reps, 12)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAuthoritativeReconciliationMaintainsUnprocessedActions() {
        // Given: Local state has 2 queued changes
        mockConnectivity.isReachable = false
        var snapshot = createSampleSnapshot()
        snapshot.exercises = [
            ExerciseSnapshot(id: "e1", name: "Ex 1", orderIndex: 0, sets: [
                SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 50, reps: 10))
            ])
        ]
        store.currentSnapshot = snapshot
        
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 55, reps: 10) // Action 1
        let action1ID = store.getActionQueue()[0].id
        
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 55, reps: 11) // Action 2
        
        XCTAssertEqual(store.getActionQueue().count, 2)
        XCTAssertEqual(store.currentSnapshot?.exercises[0].sets[0].values.reps, 11)
        
        // When: Receive snapshot where only lastProcessedActionID is Action 1
        var authoritative = snapshot
        authoritative.lastProcessedActionID = action1ID
        authoritative.exercises[0].sets[0].values.kg = 55
        authoritative.exercises[0].sets[0].values.reps = 10
        
        mockConnectivity.lastSnapshot = authoritative
        
        // Then: Verify queue has 1 item remaining (Action 2) and it's re-applied
        let expectation = expectation(description: "Wait for reconcile")
        DispatchQueue.main.async {
            XCTAssertEqual(self.store.getActionQueue().count, 1)
            XCTAssertEqual(self.store.currentSnapshot?.exercises[0].sets[0].values.kg, 55)
            XCTAssertEqual(self.store.currentSnapshot?.exercises[0].sets[0].values.reps, 11)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func createSampleSnapshot() -> ActiveWorkoutSnapshot {
        let session = WorkoutSessionPointer(id: "test-session", routineID: 1, workoutSessionID: 1)
        return ActiveWorkoutSnapshot(
            session: session,
            title: "Test Workout",
            startedAt: Date(),
            elapsedSeconds: 0,
            exercises: []
        )
    }
}

// Extension to expose private queue for testing
extension WatchWorkoutStore {
    func getActionQueue() -> [WorkoutWatchAction] {
        let mirror = Mirror(reflecting: self)
        return mirror.descendant("actionQueue") as? [WorkoutWatchAction] ?? []
    }
}

class QueuingMockConnectivityManager: ConnectivityManager {
    var sentActions: [WorkoutWatchAction] = []
    var shouldFail = false
    
    override init() {
        super.init()
        self.isReachable = true
    }
    
    override func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        if isReachable {
            self.sentActions.append(action)
            if shouldFail {
                completion?(.failure(NSError(domain: "test", code: -1)))
            } else {
                completion?(.success(()))
            }
        } else {
            completion?(.failure(NSError(domain: "ConnectivityManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device not reachable"])))
        }
    }
}
