import XCTest
@testable import Neural_Loop

final class FleetingNotesDBTests: XCTestCase {
    func testCreateFleetingNoteRequestEncodesOnlyWritableColumns() throws {
        let request = CreateFleetingNoteRequest(note: "Ship the notes tab.")

        let data = try JSONEncoder().encode(request)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(payload?["note"] as? String, "Ship the notes tab.")
        XCTAssertEqual(payload?.count, 1)
    }

    func testUpdateFleetingNoteRequestEncodesExplicitNullForUnlinking() throws {
        let request = UpdateFleetingNoteRequest(note: "Updated thought")

        let data = try JSONEncoder().encode(request)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(payload?["note"] as? String, "Updated thought")
        XCTAssertTrue(payload?["task_id"] is NSNull)
        XCTAssertEqual(payload?.count, 2)
    }

    func testCreateFleetingNoteRequestEncodesLinkedTaskWhenProvided() throws {
        let request = CreateFleetingNoteRequest(note: "Task context", task_id: 42)

        let data = try JSONEncoder().encode(request)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(payload?["task_id"] as? Int64, 42)
    }

    func testFleetingNotesErrorDescriptionsAreUserFacing() {
        XCTAssertEqual(
            FleetingNotesError.insertReturnedNoRows.localizedDescription,
            "Fleeting note could not be saved."
        )
        XCTAssertEqual(
            FleetingNotesError.updateReturnedNoRows.localizedDescription,
            "Fleeting note could not be updated."
        )
    }

    func testFleetingNoteDecodesRequestedColumns() throws {
        let data = """
        [
          {
            "id": 42,
            "created_at": "2026-04-15T09:30:00Z",
            "note": "Ship the notes tab.",
            "task_id": 42
          }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode([FleetingNote].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.id, 42)
        XCTAssertEqual(decoded.first?.note, "Ship the notes tab.")
        XCTAssertEqual(decoded.first?.task_id, 42)
        XCTAssertEqual(decoded.first?.created_at, ISO8601DateFormatter().date(from: "2026-04-15T09:30:00Z"))
    }

    func testSortedNewestFirstUsesDateThenIdentifierAsTieBreaker() {
        let date = ISO8601DateFormatter().date(from: "2026-04-15T21:00:00Z")!
        let oldest = FleetingNote(id: 1, created_at: date.addingTimeInterval(-60), note: "Old")
        let sameTimeLowerID = FleetingNote(id: 2, created_at: date, note: "Two")
        let sameTimeHigherID = FleetingNote(id: 3, created_at: date, note: "Three")

        let sorted = FleetingNote.sortedNewestFirst([sameTimeLowerID, oldest, sameTimeHigherID])

        XCTAssertEqual(sorted.map(\.id), [3, 2, 1])
    }
}
