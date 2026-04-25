import XCTest
@testable import Neural_Loop

final class WorkoutWatchSyncModelsTests: XCTestCase {
    func testActiveWorkoutSnapshotRoundTripsThroughJSON() throws {
        let snapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "session-123", routineID: 44, workoutSessionID: nil),
            title: "Lower Body Strength",
            startedAt: Date(timeIntervalSince1970: 1_774_080_000),
            elapsedSeconds: 1_245,
            exercises: [
                ExerciseSnapshot(
                    id: "exercise-1",
                    sourceExerciseID: 1001,
                    name: "Back Squat",
                    orderIndex: 0,
                    restDurationSeconds: 180,
                    isCompleted: false,
                    sets: [
                        SetSnapshot(
                            id: "set-1",
                            sourceSetID: "draft-set-1",
                            setNumber: 1,
                            values: WorkoutSetValuesSnapshot(kg: Decimal(string: "102.5"), reps: 8),
                            isCompleted: true
                        ),
                        SetSnapshot(
                            id: "set-2",
                            sourceSetID: "draft-set-2",
                            setNumber: 2,
                            values: WorkoutSetValuesSnapshot(kg: Decimal(string: "105"), reps: 6),
                            isCompleted: false
                        )
                    ]
                ),
                ExerciseSnapshot(
                    id: "exercise-2",
                    sourceExerciseID: 1002,
                    name: "Romanian Deadlift",
                    orderIndex: 1,
                    restDurationSeconds: 120,
                    isCompleted: true,
                    sets: [
                        SetSnapshot(
                            id: "set-3",
                            sourceSetID: nil,
                            setNumber: 1,
                            values: WorkoutSetValuesSnapshot(kg: Decimal(string: "80"), reps: 10),
                            isCompleted: true
                        )
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.id, "session-123")
    }

    func testSetValuesPreserveOptionalKgAndReps() throws {
        let values = [
            WorkoutSetValuesSnapshot(kg: nil, reps: nil),
            WorkoutSetValuesSnapshot(kg: Decimal(string: "102.5"), reps: nil),
            WorkoutSetValuesSnapshot(kg: nil, reps: 8),
            WorkoutSetValuesSnapshot(kg: Decimal(string: "80"), reps: 10)
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([WorkoutSetValuesSnapshot].self, from: data)

        XCTAssertEqual(decoded, values)
        XCTAssertNil(decoded[0].kg)
        XCTAssertNil(decoded[0].reps)
        XCTAssertEqual(decoded[1].kg, Decimal(string: "102.5"))
        XCTAssertNil(decoded[1].reps)
        XCTAssertNil(decoded[2].kg)
        XCTAssertEqual(decoded[2].reps, 8)
        XCTAssertEqual(decoded[3].kg, Decimal(string: "80"))
        XCTAssertEqual(decoded[3].reps, 10)
    }

    func testStableIDsSurviveRoundTrip() throws {
        let snapshot = ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "session-stable", routineID: nil, workoutSessionID: 99),
            title: "Stable IDs",
            startedAt: nil,
            elapsedSeconds: nil,
            exercises: [
                ExerciseSnapshot(
                    id: "exercise-stable",
                    sourceExerciseID: nil,
                    name: "Bench Press",
                    orderIndex: 0,
                    restDurationSeconds: nil,
                    isCompleted: false,
                    sets: [
                        SetSnapshot(
                            id: "set-stable",
                            sourceSetID: nil,
                            setNumber: 3,
                            values: WorkoutSetValuesSnapshot(kg: nil, reps: nil),
                            isCompleted: false
                        )
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data)
        let sameIDDifferentNumber = SetSnapshot(
            id: "set-stable",
            sourceSetID: nil,
            setNumber: 10,
            values: WorkoutSetValuesSnapshot(kg: nil, reps: nil),
            isCompleted: false
        )

        XCTAssertEqual(decoded.id, "session-stable")
        XCTAssertEqual(decoded.session.id, "session-stable")
        XCTAssertEqual(decoded.exercises.first?.id, "exercise-stable")
        XCTAssertEqual(decoded.exercises.first?.sets.first?.id, "set-stable")
        XCTAssertEqual(sameIDDifferentNumber.id, "set-stable")
        XCTAssertNotEqual(sameIDDifferentNumber.setNumber, decoded.exercises.first?.sets.first?.setNumber)
    }

    func testUpdateSetValuesActionDecodes() throws {
        let json = """
        {
          "type": "updateSetValues",
          "reference": {
            "session": { "id": "session-123", "routineID": 44, "workoutSessionID": null },
            "exerciseID": "exercise-1",
            "setID": "set-1"
          },
          "values": { "kg": 102.5, "reps": 8 }
        }
        """

        let payload = try JSONDecoder().decode(WorkoutWatchActionPayload.self, from: Data(json.utf8))

        guard case .updateSetValues(let action) = payload else {
            return XCTFail("Expected updateSetValues action")
        }

        XCTAssertEqual(action.reference.session.id, "session-123")
        XCTAssertEqual(action.reference.session.routineID, 44)
        XCTAssertNil(action.reference.session.workoutSessionID)
        XCTAssertEqual(action.reference.exerciseID, "exercise-1")
        XCTAssertEqual(action.reference.setID, "set-1")
        XCTAssertEqual(action.values.kg, Decimal(string: "102.5"))
        XCTAssertEqual(action.values.reps, 8)
    }

    func testToggleSetCompletionActionDecodes() throws {
        let json = """
        {
          "type": "toggleSetCompletion",
          "reference": {
            "session": { "id": "session-123" },
            "exerciseID": "exercise-1",
            "setID": "set-1"
          },
          "isCompleted": true
        }
        """

        let payload = try JSONDecoder().decode(WorkoutWatchActionPayload.self, from: Data(json.utf8))

        guard case .toggleSetCompletion(let action) = payload else {
            return XCTFail("Expected toggleSetCompletion action")
        }

        XCTAssertEqual(action.reference.session, WorkoutSessionPointer(id: "session-123", routineID: nil, workoutSessionID: nil))
        XCTAssertEqual(action.reference.exerciseID, "exercise-1")
        XCTAssertEqual(action.reference.setID, "set-1")
        XCTAssertTrue(action.isCompleted)
    }

    func testSessionActionsDecode() throws {
        let requestJSON = """
        {
          "type": "requestSnapshot",
          "session": { "id": "session-123", "routineID": 44 }
        }
        """
        let finishJSON = """
        {
          "type": "finishWorkout",
          "session": { "id": "session-123", "routineID": 44 }
        }
        """
        let expectedSession = WorkoutSessionPointer(id: "session-123", routineID: 44, workoutSessionID: nil)

        let requestPayload = try JSONDecoder().decode(WorkoutWatchActionPayload.self, from: Data(requestJSON.utf8))
        let finishPayload = try JSONDecoder().decode(WorkoutWatchActionPayload.self, from: Data(finishJSON.utf8))

        guard case .requestSnapshot(let requestAction) = requestPayload else {
            return XCTFail("Expected requestSnapshot action")
        }
        guard case .finishWorkout(let finishAction) = finishPayload else {
            return XCTFail("Expected finishWorkout action")
        }

        XCTAssertEqual(requestAction.session, expectedSession)
        XCTAssertEqual(finishAction.session, expectedSession)
    }

    func testUnknownActionTypeFailsDecoding() {
        let json = """
        {
          "type": "unknownAction",
          "session": { "id": "session-123" }
        }
        """

        XCTAssertThrowsError(try JSONDecoder().decode(WorkoutWatchActionPayload.self, from: Data(json.utf8)))
    }

    func testActionPayloadRoundTripsThroughJSON() throws {
        let session = WorkoutSessionPointer(id: "session-123", routineID: 44, workoutSessionID: nil)
        let reference = WorkoutWatchSetReference(session: session, exerciseID: "exercise-1", setID: "set-1")
        let payloads: [WorkoutWatchActionPayload] = [
            .requestSnapshot(WorkoutWatchSessionAction(session: session)),
            .updateSetValues(
                WorkoutWatchSetValuesAction(
                    reference: reference,
                    values: WorkoutSetValuesSnapshot(kg: Decimal(string: "102.5"), reps: 8)
                )
            ),
            .toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: true)),
            .finishWorkout(WorkoutWatchSessionAction(session: session))
        ]

        for payload in payloads {
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(WorkoutWatchActionPayload.self, from: data)

            XCTAssertEqual(decoded, payload)
        }
    }
}
