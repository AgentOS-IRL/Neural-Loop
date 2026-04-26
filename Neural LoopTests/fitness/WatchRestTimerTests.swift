import XCTest
@testable import Neural_Loop

// MARK: - WatchRestTimerViewModel Tests (Plan 527)

@MainActor
final class WatchRestTimerViewModelTests: XCTestCase {

    // MARK: - Timer State Transitions

    func testInitialState() {
        let vm = WatchRestTimerViewModel(
            totalSeconds: 60,
            exerciseID: "e1",
            completedSetID: "s1",
            nextSetID: "s2"
        )

        XCTAssertEqual(vm.remainingSeconds, 60)
        XCTAssertEqual(vm.timerState, .running)
        XCTAssertEqual(vm.progress, 0)
        XCTAssertEqual(vm.nextSetID, "s2")
    }

    func testStartDecrementsAndFinishes() {
        let vm = WatchRestTimerViewModel(
            totalSeconds: 3,
            exerciseID: "e1",
            completedSetID: "s1",
            nextSetID: nil
        )

        vm.start()

        // Simulate ticks via RunLoop
        let finished = expectation(description: "Timer finishes")
        let cancellable = vm.$timerState.dropFirst().sink { state in
            if state == .finished {
                finished.fulfill()
            }
        }

        wait(for: [finished], timeout: 5.0)

        XCTAssertEqual(vm.remainingSeconds, 0)
        XCTAssertEqual(vm.progress, 1.0)
        XCTAssertEqual(vm.timerState, .finished)

        cancellable.cancel()
    }

    // MARK: - Next Incomplete Set Selection

    func testResolveNextIncompleteSetFindsFirstAfterCompleted() {
        let sets: [SetSnapshot] = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s3", setNumber: 3, values: WorkoutSetValuesSnapshot(), isCompleted: false),
            SetSnapshot(id: "s4", setNumber: 4, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s5", setNumber: 5, values: WorkoutSetValuesSnapshot(), isCompleted: false),
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "Bench", orderIndex: 0, sets: sets)

        let result = WatchRestTimerViewModel.resolveNextIncompleteSet(in: exercise, after: "s2")
        XCTAssertEqual(result, "s3")
    }

    func testResolveNextIncompleteSetFromFirstSet() {
        let sets: [SetSnapshot] = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(), isCompleted: false),
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "Squat", orderIndex: 0, sets: sets)

        let result = WatchRestTimerViewModel.resolveNextIncompleteSet(in: exercise, after: "s1")
        XCTAssertEqual(result, "s2")
    }

    // MARK: - No Remaining Sets

    func testResolveNextIncompleteSetReturnsNilWhenAllCompleted() {
        let sets: [SetSnapshot] = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(), isCompleted: true),
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "Deadlift", orderIndex: 0, sets: sets)

        let result = WatchRestTimerViewModel.resolveNextIncompleteSet(in: exercise, after: "s1")
        XCTAssertNil(result)
    }

    func testResolveNextIncompleteSetReturnsNilWhenLastSet() {
        let sets: [SetSnapshot] = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "OHP", orderIndex: 0, sets: sets)

        let result = WatchRestTimerViewModel.resolveNextIncompleteSet(in: exercise, after: "s1")
        XCTAssertNil(result)
    }

    func testResolveNextIncompleteSetReturnsNilForUnknownSetID() {
        let sets: [SetSnapshot] = [
            SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: false),
        ]
        let exercise = ExerciseSnapshot(id: "e1", name: "Row", orderIndex: 0, sets: sets)

        let result = WatchRestTimerViewModel.resolveNextIncompleteSet(in: exercise, after: "unknown")
        XCTAssertNil(result)
    }

    // MARK: - Zero Rest Duration

    func testZeroDurationFinishesImmediately() {
        let vm = WatchRestTimerViewModel(
            totalSeconds: 0,
            exerciseID: "e1",
            completedSetID: "s1",
            nextSetID: "s2"
        )

        vm.start()

        XCTAssertEqual(vm.timerState, .finished)
        XCTAssertEqual(vm.remainingSeconds, 0)
        XCTAssertEqual(vm.progress, 1.0)
    }

    // MARK: - Cancellation

    func testCancelStopsTimer() {
        let vm = WatchRestTimerViewModel(
            totalSeconds: 60,
            exerciseID: "e1",
            completedSetID: "s1",
            nextSetID: "s2"
        )

        vm.start()

        // Wait for 1 tick
        let ticked = expectation(description: "Timer ticks")
        let cancellable = vm.$remainingSeconds.dropFirst().sink { seconds in
            if seconds < 60 {
                ticked.fulfill()
            }
        }

        wait(for: [ticked], timeout: 3.0)
        cancellable.cancel()

        let remainingBeforeCancel = vm.remainingSeconds
        vm.cancel()

        XCTAssertEqual(vm.timerState, .cancelled)
        XCTAssertEqual(vm.remainingSeconds, remainingBeforeCancel, "Should freeze at current value")
    }

    // MARK: - Skip with Next Set

    func testCancelPreservesNextSetID() {
        let vm = WatchRestTimerViewModel(
            totalSeconds: 60,
            exerciseID: "e1",
            completedSetID: "s1",
            nextSetID: "s2"
        )

        vm.start()
        vm.cancel()

        XCTAssertEqual(vm.timerState, .cancelled)
        XCTAssertEqual(vm.nextSetID, "s2", "nextSetID should remain available after cancellation")
    }
}

// MARK: - WatchWorkoutStore UI State Tests (Plans 528 & 529)

@MainActor
final class WatchUIStateTests: XCTestCase {

    // MARK: - Stale Draft Detection (Plan 529)

    func testIsSnapshotStaleReturnsFalseForRecentSnapshot() {
        let mockConnectivity = StoreMockConnectivityManager()
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test",
            startedAt: Date()
        )

        XCTAssertFalse(store.isSnapshotStale)
        XCTAssertNil(store.staleSnapshotAge)
    }

    func testIsSnapshotStaleReturnsTrueForOldSnapshot() {
        let mockConnectivity = StoreMockConnectivityManager()
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test",
            startedAt: Date(timeIntervalSinceNow: -48 * 3600)
        )

        XCTAssertTrue(store.isSnapshotStale)
        XCTAssertNotNil(store.staleSnapshotAge)
        XCTAssertEqual(store.staleSnapshotAge, "2 days ago")
    }

    func testDiscardStaleWorkoutClearsStore() {
        let mockConnectivity = StoreMockConnectivityManager()
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test",
            startedAt: Date(timeIntervalSinceNow: -72 * 3600)
        )

        store.discardStaleWorkout()

        XCTAssertNil(store.currentSnapshot)
    }

    // MARK: - Empty State (Plan 529)

    func testEmptyStateWhenNoSnapshot() {
        let mockConnectivity = StoreMockConnectivityManager()
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)

        XCTAssertNil(store.currentSnapshot)
        XCTAssertFalse(store.isSnapshotStale)
    }

    // MARK: - Completed Exercise (Plan 529)

    func testCompletedExerciseProgress() {
        let exercise = ExerciseSnapshot(
            id: "e1", name: "Bench", orderIndex: 0,
            isCompleted: true,
            sets: [
                SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: true),
                SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(), isCompleted: true),
            ]
        )

        XCTAssertEqual(exercise.completedSetsCount, 2)
        XCTAssertEqual(exercise.completedSetsCount, exercise.sets.count)
    }

    // MARK: - Completed Workout (Plan 529)

    func testAllExercisesCompleted() {
        let snapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test",
            exercises: [
                ExerciseSnapshot(id: "e1", name: "Bench", orderIndex: 0, isCompleted: true, sets: []),
                ExerciseSnapshot(id: "e2", name: "Squat", orderIndex: 1, isCompleted: true, sets: []),
            ]
        )

        XCTAssertTrue(snapshot.exercises.allSatisfy(\.isCompleted))
    }

    // MARK: - Pending Action Count (Plan 529)

    func testPendingActionCountUpdatesOnEnqueue() {
        let mockConnectivity = StoreMockConnectivityManager()
        mockConnectivity.isReachable = false // Prevent flushing
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test",
            exercises: [
                ExerciseSnapshot(id: "e1", name: "Bench", orderIndex: 0, sets: [
                    SetSnapshot(id: "set1", setNumber: 1, values: WorkoutSetValuesSnapshot(), isCompleted: false)
                ])
            ]
        )

        XCTAssertEqual(store.pendingActionCount, 0)

        store.updateSetValues(exerciseID: "e1", setID: "set1", kg: 50, reps: 10)
        XCTAssertEqual(store.pendingActionCount, 1)

        store.addSet(exerciseID: "e1")
        XCTAssertEqual(store.pendingActionCount, 2)
    }

    // MARK: - End Workout isFinishing (Plan 528)

    func testFinishWorkoutSetsIsFinishing() {
        let mockConnectivity = StoreMockConnectivityManager()
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test"
        )

        store.finishWorkout()

        // After success callback, isFinishing should be false and snapshot nil
        XCTAssertFalse(store.isFinishing)
        XCTAssertNil(store.currentSnapshot)
    }

    func testFinishWorkoutResetsIsFinishingOnFailure() {
        let mockConnectivity = StoreMockConnectivityManager()
        mockConnectivity.shouldFail = true
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test"
        )

        store.finishWorkout()

        XCTAssertFalse(store.isFinishing)
        XCTAssertNotNil(store.currentSnapshot, "Should keep snapshot on failure")
    }

    // MARK: - CompletedSetInfo Coordination (Plan 527)

    func testLastCompletedSetInfoClearedOnClearStore() {
        let mockConnectivity = StoreMockConnectivityManager()
        let store = WatchWorkoutStore(connectivityManager: mockConnectivity)
        store.currentSnapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "s1"),
            title: "Test"
        )
        store.lastCompletedSetInfo = CompletedSetInfo(
            exerciseID: "e1", setID: "s1", restDurationSeconds: 90
        )

        store.clearStore()

        XCTAssertNil(store.lastCompletedSetInfo)
        XCTAssertNil(store.currentSnapshot)
    }
}

// Note: StoreMockConnectivityManager is defined in WatchWorkoutStoreTests.swift
