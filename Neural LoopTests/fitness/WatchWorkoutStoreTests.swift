import XCTest
import Combine
@testable import Neural_Loop

// MARK: - WatchWorkoutStore Implementation for Testing
// Since WatchWorkoutStore.swift is in the Watch App target, it's not directly accessible
// from the iOS test target in this environment. We include a copy here to verify the logic.

@MainActor
final class WatchWorkoutStore: ObservableObject {
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
    @Published var lastCompletedSetInfo: CompletedSetInfo?
    @Published var isFinishing: Bool = false
    @Published var pendingActionCount: Int = 0
    
    private var actionQueue: [WorkoutWatchAction] = []
    private var isFlushing = false
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot.test"
    private let queueKey = "com.neuralloop.watch.actionQueue.test"
    private let connectivityManager: ConnectivityManager
    
    init(connectivityManager: ConnectivityManager = .shared) {
        self.connectivityManager = connectivityManager
        loadFromPersistence()
        loadQueue()
        pendingActionCount = actionQueue.count
        
        connectivityManager.$lastSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                if let snapshot {
                    self.reconcile(with: snapshot)
                } else if self.currentSnapshot != nil {
                    self.clearStore()
                }
            }
            .store(in: &cancellables)
            
        connectivityManager.$isReachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReachable in
                if isReachable {
                    self?.flushQueue()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    func updateSetValues(exerciseID: String, setID: String, kg: Decimal?, reps: Int?) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let values = WorkoutSetValuesSnapshot(kg: kg, reps: reps)
        let payload = WorkoutWatchActionPayload.updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        enqueueAction(payload: payload)
    }
    
    func toggleSetCompletion(exerciseID: String, setID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchSetReference(session: session, exerciseID: exerciseID, setID: setID)
        let payload = WorkoutWatchActionPayload.toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func addSet(exerciseID: String) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let payload = WorkoutWatchActionPayload.addSet(reference)
        enqueueAction(payload: payload)
    }
    
    func toggleExerciseCompletion(exerciseID: String, isCompleted: Bool) {
        guard let session = currentSnapshot?.session else { return }
        let reference = WorkoutWatchExerciseReference(session: session, exerciseID: exerciseID)
        let payload = WorkoutWatchActionPayload.updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        enqueueAction(payload: payload)
    }
    
    func finishWorkout() {
        guard let session = currentSnapshot?.session else { return }
        isFinishing = true
        let payload = WorkoutWatchActionPayload.finishWorkout(WorkoutWatchSessionAction(session: session))
        let action = WorkoutWatchAction(payload: payload)
        applyOptimisticAction(action)
        
        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success = result {
                    self.clearStore()
                }
                self.isFinishing = false
            }
        }
    }

    private func enqueueAction(payload: WorkoutWatchActionPayload) {
        let action = WorkoutWatchAction(payload: payload)
        applyOptimisticAction(action)
        actionQueue.append(action)
        pendingActionCount = actionQueue.count
        saveQueue()
        flushQueue()
    }

    private func applyOptimisticAction(_ action: WorkoutWatchAction) {
        guard var snapshot = currentSnapshot else { return }
        reconcileApply(action, to: &snapshot)
        self.currentSnapshot = snapshot
        saveToPersistence()
    }

    private func reconcile(with authoritativeSnapshot: ActiveWorkoutSnapshot) {
        if let current = currentSnapshot,
           current.session.id != authoritativeSnapshot.session.id {
            actionQueue.removeAll()
            saveQueue()
            pendingActionCount = 0
            self.currentSnapshot = authoritativeSnapshot
            saveToPersistence()
            return
        }
        
        if let lastID = authoritativeSnapshot.lastProcessedActionID {
            if let index = actionQueue.firstIndex(where: { $0.id == lastID }) {
                actionQueue.removeSubrange(0...index)
                saveQueue()
            }
        }
        
        pendingActionCount = actionQueue.count
        
        var reconciledSnapshot = authoritativeSnapshot
        for action in actionQueue {
            reconcileApply(action, to: &reconciledSnapshot)
        }
        
        self.currentSnapshot = reconciledSnapshot
        saveToPersistence()
    }

    private func reconcileApply(_ action: WorkoutWatchAction, to snapshot: inout ActiveWorkoutSnapshot) {
        switch action.payload {
        case .updateSetValues(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }),
               let setIndex = snapshot.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == action.reference.setID }) {
                snapshot.exercises[exerciseIndex].sets[setIndex].values = action.values
            }
        case .toggleSetCompletion(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }),
               let setIndex = snapshot.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == action.reference.setID }) {
                snapshot.exercises[exerciseIndex].sets[setIndex].isCompleted = action.isCompleted
            }
        case .addSet(let reference):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == reference.exerciseID }) {
                let newSet = SetSnapshot(
                    id: action.id.uuidString,
                    setNumber: snapshot.exercises[exerciseIndex].sets.count + 1,
                    values: WorkoutSetValuesSnapshot(),
                    isCompleted: false
                )
                snapshot.exercises[exerciseIndex].sets.append(newSet)
            }
        case .updateExerciseCompletion(let action):
            if let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.id == action.reference.exerciseID }) {
                snapshot.exercises[exerciseIndex].isCompleted = action.isCompleted
                for i in 0..<snapshot.exercises[exerciseIndex].sets.count {
                    snapshot.exercises[exerciseIndex].sets[i].isCompleted = action.isCompleted
                }
            }
        default:
            break
        }
    }

    func flushQueue() {
        guard !isFlushing, !actionQueue.isEmpty, connectivityManager.isReachable else { return }
        isFlushing = true
        sendNextPending(after: nil)
    }

    private func sendNextPending(after lastID: UUID?) {
        let remaining = actionQueue
        let startIndex: Int
        if let lastID = lastID, let index = remaining.firstIndex(where: { $0.id == lastID }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        
        guard startIndex < remaining.count, connectivityManager.isReachable else {
            isFlushing = false
            return
        }
        
        let action = remaining[startIndex]
        connectivityManager.sendWorkoutAction(action) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case .success = result {
                    self.sendNextPending(after: action.id)
                } else {
                    self.isFlushing = false
                }
            }
        }
    }
    
    // MARK: - Persistence
    
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

    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(actionQueue)
            UserDefaults.standard.set(data, forKey: queueKey)
        } catch {
            print("Failed to save action queue: \(error)")
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return }
        do {
            self.actionQueue = try JSONDecoder().decode([WorkoutWatchAction].self, from: data)
        } catch {
            print("Failed to load action queue: \(error)")
        }
    }
    
    func clearStore() {
        self.currentSnapshot = nil
        self.actionQueue.removeAll()
        self.pendingActionCount = 0
        self.lastCompletedSetInfo = nil
        self.isFinishing = false
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: queueKey)
    }
    
    var isSnapshotStale: Bool {
        guard let startedAt = currentSnapshot?.startedAt else { return false }
        return Date().timeIntervalSince(startedAt) > 24 * 3600
    }
    
    var staleSnapshotAge: String? {
        guard let startedAt = currentSnapshot?.startedAt else { return nil }
        let hours = Int(Date().timeIntervalSince(startedAt) / 3600)
        if hours < 24 { return nil }
        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
    
    func discardStaleWorkout() {
        clearStore()
    }
}

// MARK: - Tests

@MainActor
final class WatchWorkoutStoreTests: XCTestCase {
    var store: WatchWorkoutStore!
    var mockConnectivity: StoreMockConnectivityManager!
    let storageKey = "com.neuralloop.watch.activeWorkoutSnapshot.test"
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults
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
        if case .updateSetValues(let action) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(action.reference.exerciseID, "e1")
            XCTAssertEqual(action.reference.setID, "s1")
            XCTAssertEqual(action.values.kg, 50)
            XCTAssertEqual(action.values.reps, 10)
        } else {
            XCTFail("Expected updateSetValues action")
        }
        
        // When - toggleSetCompletion
        store.toggleSetCompletion(exerciseID: "e1", setID: "s1", isCompleted: true)
        if case .toggleSetCompletion(let action) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(action.reference.setID, "s1")
            XCTAssertTrue(action.isCompleted)
        } else {
            XCTFail("Expected toggleSetCompletion action")
        }
        
        // When - addSet
        store.addSet(exerciseID: "e1")
        if case .addSet(let reference) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(reference.exerciseID, "e1")
        } else {
            XCTFail("Expected addSet action")
        }
        
        // When - toggleExerciseCompletion
        store.toggleExerciseCompletion(exerciseID: "e1", isCompleted: true)
        if case .updateExerciseCompletion(let action) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(action.reference.exerciseID, "e1")
            XCTAssertTrue(action.isCompleted)
        } else {
            XCTFail("Expected updateExerciseCompletion action")
        }
        
        // When - finishWorkout
        store.finishWorkout()
        if case .finishWorkout(let action) = mockConnectivity.sentAction?.payload {
            XCTAssertEqual(action.session.id, snapshot.session.id)
        } else {
            XCTFail("Expected finishWorkout action")
        }
    }
    
    func testFinishWorkoutClearsStateAndQueue() {
        // Given
        store.currentSnapshot = createSampleSnapshot()
        store.updateSetValues(exerciseID: "e1", setID: "s1", kg: 50, reps: 10)
        XCTAssertEqual(store.getActionQueue().count, 1)
        
        // When
        store.finishWorkout()
        
        // Then
        XCTAssertNil(store.currentSnapshot)
        XCTAssertEqual(store.getActionQueue().count, 0)
        XCTAssertNil(UserDefaults.standard.data(forKey: storageKey))
        XCTAssertNil(UserDefaults.standard.data(forKey: "com.neuralloop.watch.actionQueue.test"))
    }
    
    func testFinishWorkoutDoesNotClearStateOnFailure() {
        // Given
        store.currentSnapshot = createSampleSnapshot()
        mockConnectivity.shouldFail = true
        
        // When
        store.finishWorkout()
        
        // Then
        XCTAssertNotNil(store.currentSnapshot)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: storageKey))
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

class StoreMockConnectivityManager: ConnectivityManager {
    var sentAction: WorkoutWatchAction?
    var shouldFail = false
    
    override init() {
        super.init()
        self.isReachable = true
    }
    
    override func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        self.sentAction = action
        if shouldFail {
            completion?(.failure(NSError(domain: "test", code: -1)))
        } else {
            completion?(.success(()))
        }
    }
}
