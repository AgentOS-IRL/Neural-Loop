import Darwin
import XCTest
@testable import Neural_Loop

final class WorkoutDatabaseModelTests: XCTestCase {
    func testExerciseTypeEncodesDatabaseValues() throws {
        XCTAssertEqual(ExerciseType.repBased.rawValue, "rep-based")
        XCTAssertEqual(ExerciseType.duration.rawValue, "duration")

        let encoded = try JSONEncoder().encode(ExerciseType.repBased)
        let decodedString = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(decodedString, "\"rep-based\"")

        let decoded = try JSONDecoder().decode(ExerciseType.self, from: Data("\"duration\"".utf8))
        XCTAssertEqual(decoded, .duration)
    }

    func testCreateExerciseRequestEncodesOnlyWritableColumns() throws {
        let request = CreateExerciseRequest(
            name: "Back Squat",
            type: .repBased,
            equipment_id: 7
        )

        let payload = try encodedPayload(request)

        XCTAssertEqual(payload["name"] as? String, "Back Squat")
        XCTAssertEqual(payload["type"] as? String, "rep-based")
        XCTAssertEqual(payload["equipment_id"] as? Int, 7)
        XCTAssertNil(payload["id"])
        XCTAssertEqual(payload.count, 3)
    }

    func testCreateWorkoutSessionRequestCanOmitDateForDatabaseDefault() throws {
        let request = CreateWorkoutSessionRequest(
            start_time: "09:30:00",
            end_time: nil,
            session_type: "Strength",
            notes: "Lower body"
        )

        let payload = try encodedPayload(request)

        XCTAssertNil(payload["date"])
        XCTAssertEqual(payload["start_time"] as? String, "09:30:00")
        XCTAssertNil(payload["end_time"])
        XCTAssertEqual(payload["session_type"] as? String, "Strength")
        XCTAssertEqual(payload["notes"] as? String, "Lower body")
        XCTAssertNil(payload["id"])
        XCTAssertEqual(payload.count, 3)
    }

    func testWorkoutSessionDateEncodingPreservesCurrentCalendarDay() throws {
        let originalTimeZone = ProcessInfo.processInfo.environment["TZ"]
        setenv("TZ", "America/Los_Angeles", 1)
        tzset()
        NSTimeZone.resetSystemTimeZone()
        defer {
            if let originalTimeZone {
                setenv("TZ", originalTimeZone, 1)
            } else {
                unsetenv("TZ")
            }
            tzset()
            NSTimeZone.resetSystemTimeZone()
        }

        let request = CreateWorkoutSessionRequest(
            date: localDate("2026-04-22 20:30:00", timeZoneIdentifier: "America/Los_Angeles"),
            start_time: nil,
            end_time: nil,
            session_type: "Strength",
            notes: nil
        )

        let payload = try encodedPayload(request)

        XCTAssertEqual(payload["date"] as? String, "2026-04-22")
    }

    func testCreateWorkoutSetRequestEncodesWritableColumns() throws {
        let request = CreateWorkoutSetRequest(
            workout_session_id: 11,
            exercise_id: 22,
            set_number: 3,
            reps: 8,
            weight: Decimal(string: "102.5"),
            superset_group_id: 1
        )

        let payload = try encodedPayload(request)

        XCTAssertEqual(payload["workout_session_id"] as? Int, 11)
        XCTAssertEqual(payload["exercise_id"] as? Int, 22)
        XCTAssertEqual(payload["set_number"] as? Int, 3)
        XCTAssertEqual(payload["reps"] as? Int, 8)
        XCTAssertEqual((payload["weight"] as? NSNumber)?.decimalValue, Decimal(string: "102.5"))
        XCTAssertEqual(payload["superset_group_id"] as? Int, 1)
        XCTAssertNil(payload["id"])
        XCTAssertEqual(payload.count, 6)
    }

    func testUpdateRequestsEncodeNullForClearedNullableColumns() throws {
        let exercise = UpdateExerciseRequest(
            name: "Push-Up",
            type: .repBased,
            equipment_id: nil
        )
        let exercisePayload = try encodedPayload(exercise)

        XCTAssertTrue(exercisePayload["equipment_id"] is NSNull)
        XCTAssertEqual(exercisePayload.count, 3)

        let session = UpdateWorkoutSessionRequest(
            date: workoutDate("2026-04-22"),
            start_time: nil,
            end_time: nil,
            session_type: "Mixed",
            notes: nil
        )
        let sessionPayload = try encodedPayload(session)

        XCTAssertEqual(sessionPayload["date"] as? String, "2026-04-22")
        XCTAssertTrue(sessionPayload["start_time"] is NSNull)
        XCTAssertTrue(sessionPayload["end_time"] is NSNull)
        XCTAssertTrue(sessionPayload["notes"] is NSNull)
        XCTAssertEqual(sessionPayload.count, 5)
    }

    func testRowModelsDecodeRepresentativeSupabaseJSON() throws {
        let equipment = try JSONDecoder().decode(
            Equipment.self,
            from: Data(#"{"id":1,"name":"Barbell"}"#.utf8)
        )
        XCTAssertEqual(equipment, Equipment(id: 1, name: "Barbell"))

        let exercise = try JSONDecoder().decode(
            Exercise.self,
            from: Data(#"{"id":2,"name":"Back Squat","type":"rep-based","equipment_id":1}"#.utf8)
        )
        XCTAssertEqual(exercise.type, .repBased)
        XCTAssertEqual(exercise.equipment_id, 1)

        let routineExercise = try JSONDecoder().decode(
            RoutineExercise.self,
            from: Data("""
            {
              "id": 3,
              "routine_id": 4,
              "exercise_id": 2,
              "order_index": 1,
              "target_sets": 5,
              "target_reps": 5,
              "rest_seconds": 180,
              "superset_group_id": null
            }
            """.utf8)
        )
        XCTAssertEqual(routineExercise.target_sets, 5)
        XCTAssertEqual(routineExercise.rest_seconds, 180)

        let session = try JSONDecoder().decode(
            WorkoutSession.self,
            from: Data("""
            {
              "id": 5,
              "date": "2026-04-22",
              "start_time": "09:30:00",
              "end_time": "10:15:00",
              "session_type": "Strength",
              "notes": "Lower body"
            }
            """.utf8)
        )
        XCTAssertEqual(session.id, 5)
        XCTAssertEqual(session.date, workoutDate("2026-04-22"))
        XCTAssertEqual(session.start_time, "09:30:00")

        let set = try JSONDecoder().decode(
            WorkoutSet.self,
            from: Data("""
            {
              "id": 6,
              "workout_session_id": 5,
              "exercise_id": 2,
              "set_number": 1,
              "reps": 8,
              "weight": 102.5,
              "superset_group_id": 1
            }
            """.utf8)
        )
        XCTAssertEqual(set.weight, Decimal(string: "102.5"))
        XCTAssertEqual(set.superset_group_id, 1)

        let cardioLog = try JSONDecoder().decode(
            CardioLog.self,
            from: Data("""
            {
              "id": 7,
              "workout_session_id": 5,
              "exercise_id": 8,
              "distance_meters": 5000,
              "duration_minutes": 24.5
            }
            """.utf8)
        )
        XCTAssertEqual(cardioLog.distance_meters, Decimal(5000))
        XCTAssertEqual(cardioLog.duration_minutes, Decimal(string: "24.5"))
    }

    func testWorkoutDatabaseErrorDescriptionsAreUserFacing() {
        XCTAssertEqual(
            WorkoutDatabaseError.insertReturnedNoRows.localizedDescription,
            "Workout record could not be saved."
        )
        XCTAssertEqual(
            WorkoutDatabaseError.updateReturnedNoRows.localizedDescription,
            "Workout record could not be updated."
        )
        XCTAssertEqual(
            WorkoutDatabaseError.missingIdentifier.localizedDescription,
            "Workout record is missing its database identifier."
        )
    }

    private func encodedPayload<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func workoutDate(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }

    private func localDate(_ value: String, timeZoneIdentifier: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)!
    }
}
