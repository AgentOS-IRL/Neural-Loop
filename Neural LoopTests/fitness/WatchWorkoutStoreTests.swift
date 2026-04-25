import XCTest
import Combine
@testable import Neural_Loop

// MARK: - WatchWorkoutStore Implementation for Testing
// Since WatchWorkoutStore.swift is in the Watch App target, it's not directly accessible
// from the iOS test target in this environment. We include a copy here to verify the logic.

@MainActor
final class WatchWorkoutStore: ObservableObject {
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
    
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot.test"
    private let connectivityManager: ConnectivityManager
    
    init(connectivityManager: ConnectivityManager = .shared) {
        self.connectivityManager = connectivityManager
        loadFromPersistence()
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self = self, let snapshot = snapshot else { return }
                self.currentSnapshot = snapshot
                self.saveToPersistence()
            }
            .store(in: &cancellables)
    }
    
    func updateSetValues(exerciseID: String, setID: String, kg: Decimal?, reps: Int?) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let values = WorkoutSetValuesSnapshot(kg: kg, reps: reps)
        let action = WorkoutWatchActionPayload.updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        connectivityManager.sendWorkoutAction(action)
    }
    
    func toggleSetCompletion(exerciseID: String, setID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let action = WorkoutWatchActionPayload.toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        connectivityManager.sendWorkoutAction(action)
    }
    
    func addSet(exerciseID: String) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let action = WorkoutWatchActionPayload.addSet(reference)
        connectivityManager.sendWorkoutAction(action)
    }
    
    func toggleExerciseCompletion(exerciseID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let action = WorkoutWatchActionPayload.updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        connectivityManager.sendWorkoutAction(action)
    }
    
    func finishWorkout() {
        guard let session = currentSnapshot?.session else { return }
        let action = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
        connectivityManager.sendWorkoutAction(action)
        clearStore()
    }
    
    private func saveToPersistence() {
        guard let currentSnapshot = currentSnapshot else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        do {
            let data = try JSONEncoder().encode(currentSnapshot)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save snapshot to persistence: \(error)")
        }
    }
    
    private func loadFromPersistence() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let snapshot = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data)
            self.currentSnapshot = snapshot
        } catch {
            print("Failed to load snapshot from persistence: \(error)")
        }
    }
    
    func clearStore() {
        self.currentSnapshot = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - Tests

@MainActor
final class WatchWorkoutStoreTests: XCTestCase {
    var store: WatchWorkoutStore!
    var mockConnectivity: MockConnectivityManager!
    let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot.test"
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: storageKey)
        mockConnectivity = MockConnectivityManager()
        store = WatchWorkoutStore(connectivityManager: mockConnectivity)
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        store = nil
        mockConnectivity = nil
        super.tearDown()
    }
    
    func testInitializationRestoresFromUserDefaults() {
        // Given
        let snapshot = createSampleSnapshot()
        let data = try! JSONEncoder().encode(snapshot)
        UserDefaults.standard.set(data, forKey: storageKey)
        
        // When
        let newStore = WatchWorkoutStore(connectivityManager: mockConnectivity)
        
        // Then
        XCTAssertEqual(newStore.currentSnapshot?.id, snapshot.id)
    }
    
    func testSnapshotUpdatePersistsToUserDefaults() {
        // When
        let snapshot = createSampleSnapshot()
        mockConnectivity.lastSnapshot = snapshot
        
        // Wait for Combine to propagate
        let expectation = expectation(description: "Wait for snapshot update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(store.currentSnapshot?.id, snapshot.id)
        let data = UserDefaults.standard.data(forKey: storageKey)
        XCTAssertNotNil(data)
        let loadedSnapshot = try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data!)
        XCTAssertEqual(loadedSnapshot?.id, snapshot.id)
    }
    
    func testActionMethodsSendCorrectPayloads() {
        // Given
        let snapshot = createSampleSnapshot()
        store.currentSnapshot = snapshot
        
        // When - updateSetValues
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 50, reps: 10)
        
        // Then
        if case .updateSetValues(let action) = mockConnectivity.sentAction {
            XCTAssertEqual(action.reference.exerciseID, "e1")
            XCTAssertEqual(action.reference.setID, "s1")
            XCTAssertEqual(action.values.kg, 50)
            XCTAssertEqual(action.values.reps, 10)
        } else {
            XCTFail("Expected updateSetValues action")
        }
        
        // When - toggleSetCompletion
        store.toggleSetCompletion(exerciseID: "e1", setID: "s1", isCompleted: true)
        if case .toggleSetCompletion(let action) = mockConnectivity.sentAction {
            XCTAssertEqual(action.reference.setID, "s1")
            XCTAssertTrue(action.isCompleted)
        } else {
            XCTFail("Expected toggleSetCompletion action")
        }
        
        // When - addSet
        store.addSet(exerciseID: "e1")
        if case .addSet(let reference) = mockConnectivity.sentAction {
            XCTAssertEqual(reference.exerciseID, "e1")
        } else {
            XCTFail("Expected addSet action")
        }
        
        // When - toggleExerciseCompletion
        store.toggleExerciseCompletion(exerciseID: "e1", isCompleted: true)
        if case .updateExerciseCompletion(let action) = mockConnectivity.sentAction {
            XCTAssertEqual(action.reference.exerciseID, "e1")
            XCTAssertTrue(action.isCompleted)
        } else {
            XCTFail("Expected updateExerciseCompletion action")
        }
        
        // When - finishWorkout
        store.finishWorkout()
        if case .finishWorkout(let action) = mockConnectivity.sentAction {
            XCTAssertEqual(action.session.id, snapshot.session.id)
        } else {
            XCTFail("Expected finishWorkout action")
        }
    }
    
    func testFinishWorkoutClearsState() {
        // Given
        store.currentSnapshot = createSampleSnapshot()
        
        // When
        store.finishWorkout()
        
        // Then
        XCTAssertNil(store.currentSnapshot)
        XCTAssertNil(UserDefaults.standard.data(forKey: storageKey))
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

class MockConnectivityManager: ConnectivityManager {
    var sentAction: WorkoutWatchActionPayload?
    
    override init() {
        super.init()
    }
    
    override func sendWorkoutAction(_ action: WorkoutWatchActionPayload, completion: ((Result<Void, Error>) -> Void)? = nil) {
        self.sentAction = action
        completion?(.success(()))
    }
}
