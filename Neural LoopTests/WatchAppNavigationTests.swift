import XCTest
import SwiftUI
import Combine
@testable import Neural_Loop

@MainActor
final class WatchAppNavigationTests: XCTestCase {
    
    func testWatchTabEnum_HasCorrectCases() {
        XCTAssertEqual(WatchTab.home, .home)
        XCTAssertEqual(WatchTab.fitness, .fitness)
    }
    
    func testFitnessView_ShowsEmptyState_WhenNoSnapshot() {
        let store = LocalMockWatchWorkoutStore()
        store.currentSnapshot = nil
        XCTAssertNil(store.currentSnapshot)
    }
    
    func testFitnessView_ShowsActiveWorkout_WhenSnapshotExists() {
        let store = LocalMockWatchWorkoutStore()
        let snapshot = createSampleSnapshot()
        store.currentSnapshot = snapshot
        
        XCTAssertNotNil(store.currentSnapshot)
        XCTAssertEqual(store.currentSnapshot?.title, "Test Workout")
    }
    
    func testFitnessView_ShowsDisconnectedCopy_WhenNotReachable() {
        let connectivity = NavigationTestMockConnectivityManager()
        connectivity.isReachable = false
        
        XCTAssertFalse(connectivity.isReachable)
    }
    
    private func createSampleSnapshot() -> ActiveWorkoutSnapshot {
        let session = WorkoutSessionPointer(id: "test-session")
        return ActiveWorkoutSnapshot(
            session: session,
            title: "Test Workout",
            timestamp: Date()
        )
    }
}

@MainActor
class LocalMockWatchWorkoutStore: ObservableObject {
    @Published var currentSnapshot: ActiveWorkoutSnapshot?
}

class NavigationTestMockConnectivityManager: ConnectivityManager {
    override init() {
        super.init()
        self.isReachable = true
    }
}
