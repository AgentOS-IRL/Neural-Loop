import XCTest
import Combine
import SwiftUI
@testable import Neural_Loop

// MARK: - Re-implementing ViewModel for Testing
// Since the Watch App target files are not directly accessible from the iOS test target,
// we include the logic here to verify it.

@MainActor
final class WatchSetEntryViewModel: ObservableObject {
    @Published var kg: Double = 0
    @Published var reps: Int = 0
    @Published var isCompleted: Bool = false
    
    @Published var initialKg: Double = 0
    @Published var initialReps: Int = 0
    @Published var initialIsCompleted: Bool = false
    
    let exerciseID: String
    let setID: String
    var store: WatchWorkoutStore
    
    init(exerciseID: String, setID: String, store: WatchWorkoutStore, set: SetSnapshot?) {
        self.exerciseID = exerciseID
        self.setID = setID
        self.store = store
        
        if let set = set {
            let currentKg = (set.values.kg as NSDecimalNumber?)?.doubleValue ?? 0
            let currentReps = set.values.reps ?? 0
            
            self.kg = currentKg
            self.reps = currentReps
            self.isCompleted = set.isCompleted
            
            self.initialKg = currentKg
            self.initialReps = currentReps
            self.initialIsCompleted = set.isCompleted
        }
    }
    
    func adjustKg(by amount: Double) {
        kg = clamp(kg + amount, in: 0...500)
    }
    
    func adjustReps(by amount: Int) {
        reps = Int(clamp(Double(reps + amount), in: 0...100))
    }
    
    func handleDone(dismiss: () -> Void) {
        let kgChanged = kg != initialKg
        let repsChanged = reps != initialReps
        let completionChanged = isCompleted != initialIsCompleted
        
        if kgChanged || repsChanged {
            store.updateSetValues(
                exerciseID: exerciseID,
                setID: setID,
                kg: Decimal(kg),
                reps: reps
            )
        }
        
        if completionChanged {
            store.toggleSetCompletion(
                exerciseID: exerciseID,
                setID: setID,
                isCompleted: isCompleted
            )
        }
        
        dismiss()
    }
    
    private func clamp(_ value: Double, in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Tests

@MainActor
final class WatchSetEntryTests: XCTestCase {
    var store: WatchWorkoutStore!
    var mockConnectivity: SetEntryMockConnectivityManager!
    
    override func setUp() {
        super.setUp()
        mockConnectivity = SetEntryMockConnectivityManager()
        store = WatchWorkoutStore(connectivityManager: mockConnectivity)
    }
    
    func testValueClamping() {
        let viewModel = WatchSetEntryViewModel(
            exerciseID: "e1",
            setID: "s1",
            store: store,
            set: nil
        )
        
        // KG clamping high
        viewModel.kg = 500
        viewModel.adjustKg(by: 10)
        XCTAssertEqual(viewModel.kg, 500)
        
        // KG clamping low
        viewModel.kg = 0
        viewModel.adjustKg(by: -1)
        XCTAssertEqual(viewModel.kg, 0)
        
        // Reps clamping high
        viewModel.reps = 100
        viewModel.adjustReps(by: 5)
        XCTAssertEqual(viewModel.reps, 100)
        
        // Reps clamping low
        viewModel.reps = 0
        viewModel.adjustReps(by: -1)
        XCTAssertEqual(viewModel.reps, 0)
    }
    
    func testActionPayloads() {
        let set = SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 50, reps: 10), isCompleted: false)
        let viewModel = WatchSetEntryViewModel(
            exerciseID: "e1",
            setID: "s1",
            store: store,
            set: set
        )
        
        // Mock current snapshot in store so it can find session
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "session1"),
            title: "Workout",
            exercises: []
        )
        
        viewModel.kg = 55.5
        viewModel.reps = 12
        viewModel.isCompleted = true
        
        viewModel.handleDone(dismiss: {})
        
        // Verify updateSetValues call
        let updateAction = mockConnectivity.sentActions.compactMap { action -> WorkoutWatchSetValuesAction? in
            if case .updateSetValues(let a) = action.payload { return a }
            return nil
        }.first
        
        XCTAssertNotNil(updateAction)
        XCTAssertEqual(updateAction?.values.kg, Decimal(55.5))
        XCTAssertEqual(updateAction?.values.reps, 12)
        
        // Verify toggleSetCompletion call
        let completionAction = mockConnectivity.sentActions.compactMap { action -> WorkoutWatchSetCompletionAction? in
            if case .toggleSetCompletion(let a) = action.payload { return a }
            return nil
        }.first
        
        XCTAssertNotNil(completionAction)
        XCTAssertTrue(completionAction?.isCompleted ?? false)
    }
    
    func testUnchangedValueHandling() {
        let set = SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 50, reps: 10), isCompleted: false)
        let viewModel = WatchSetEntryViewModel(
            exerciseID: "e1",
            setID: "s1",
            store: store,
            set: set
        )
        
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "session1"),
            title: "Workout",
            exercises: []
        )
        
        viewModel.handleDone(dismiss: {})
        
        XCTAssertEqual(mockConnectivity.sentActions.count, 0, "No actions should be sent if nothing changed")
    }
    
    func testMarkingSetComplete() {
        let set = SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 50, reps: 10), isCompleted: false)
        let viewModel = WatchSetEntryViewModel(
            exerciseID: "e1",
            setID: "s1",
            store: store,
            set: set
        )
        
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "session1"),
            title: "Workout",
            exercises: []
        )
        
        viewModel.isCompleted = true
        viewModel.handleDone(dismiss: {})
        
        XCTAssertEqual(mockConnectivity.sentActions.count, 1)
        if case .toggleSetCompletion(let action) = mockConnectivity.sentActions.first?.payload {
            XCTAssertTrue(action.isCompleted)
        } else {
            XCTFail("Expected toggleSetCompletion action")
        }
    }
    
    func testInitialStateLoading() {
        let set = SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 75.5, reps: 8), isCompleted: true)
        let viewModel = WatchSetEntryViewModel(
            exerciseID: "e1",
            setID: "s1",
            store: store,
            set: set
        )
        
        XCTAssertEqual(viewModel.kg, 75.5)
        XCTAssertEqual(viewModel.reps, 8)
        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertEqual(viewModel.initialKg, 75.5)
        XCTAssertEqual(viewModel.initialReps, 8)
        XCTAssertTrue(viewModel.initialIsCompleted)
    }
}

class SetEntryMockConnectivityManager: ConnectivityManager {
    var sentActions: [WorkoutWatchAction] = []
    
    override init() {
        super.init()
        self.isReachable = true
    }
    
    override func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        self.sentActions.append(action)
        completion?(.success(()))
    }
}
