import XCTest
import WatchConnectivity
@testable import Neural_Loop

final class ConnectivityManagerTests: XCTestCase {
    var sut: ConnectivityManager!

    override func setUp() {
        super.setUp()
        sut = ConnectivityManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testReceiveValidSnapshot() {
        let expectation = self.expectation(description: "Snapshot received")
        let snapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "test-session"),
            title: "Test Workout",
            startedAt: Date(),
            elapsedSeconds: 0,
            exercises: []
        )

        let data = try! JSONEncoder().encode(snapshot)
        let message: [String: Any] = [
            "msgType": "workoutSnapshot",
            "payload": data
        ]

        sut.snapshotHandler = { receivedSnapshot in
            XCTAssertEqual(receivedSnapshot.id, snapshot.id)
            XCTAssertEqual(receivedSnapshot.title, snapshot.title)
            expectation.fulfill()
        }

        sut.session(WCSession.default, didReceiveMessage: message)

        waitForExpectations(timeout: 2.0)
        XCTAssertEqual(sut.lastSnapshot?.id, snapshot.id)
    }

    func testReceiveValidAction() {
        let expectation = self.expectation(description: "Action received")
        let action = WorkoutWatchActionPayload.requestSnapshot(
            WorkoutWatchSessionAction(session: WorkoutSessionPointer(id: "test-session"))
        )

        let data = try! JSONEncoder().encode(action)
        let message: [String: Any] = [
            "msgType": "workoutAction",
            "payload": data
        ]

        sut.actionHandler = { receivedAction in
            if case .requestSnapshot(let receivedActionPayload) = receivedAction {
                XCTAssertEqual(receivedActionPayload.session.id, "test-session")
            } else {
                XCTFail("Wrong action type")
            }
            expectation.fulfill()
        }

        sut.session(WCSession.default, didReceiveMessage: message)

        waitForExpectations(timeout: 2.0)
        XCTAssertNotNil(sut.lastAction)
    }

    func testReceiveLegacyTextMessage() {
        let expectation = self.expectation(description: "Text received")
        let message = ["text": "hello world"]
        
        sut.session(WCSession.default, didReceiveMessage: message)

        // Using a small delay to allow for DispatchQueue.main.async in SUT
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.sut.receivedMessage, "hello world")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testUnknownMessageTypeHandling() {
        let message: [String: Any] = [
            "msgType": "unknownType",
            "payload": Data()
        ]

        // Should not crash
        sut.session(WCSession.default, didReceiveMessage: message)
    }

    func testMalformedPayloadRejection() {
        let expectation = self.expectation(description: "Error handler called")
        let message: [String: Any] = [
            "msgType": "workoutSnapshot",
            "payload": "not data".data(using: .utf8)!
        ]

        sut.errorHandler = { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        sut.session(WCSession.default, didReceiveMessage: message)

        waitForExpectations(timeout: 2.0)
        XCTAssertNil(sut.lastSnapshot)
    }
}
