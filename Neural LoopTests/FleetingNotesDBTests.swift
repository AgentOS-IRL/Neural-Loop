import XCTest
@testable import Neural_Loop

final class FleetingNotesDBTests: XCTestCase {
    func testFleetingNoteDecodesRequestedColumns() throws {
        let data = """
        [
          {
            "id": 42,
            "created_at": "2026-04-15T09:30:00Z",
            "note": "Ship the notes tab."
          }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode([FleetingNote].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.id, 42)
        XCTAssertEqual(decoded.first?.note, "Ship the notes tab.")
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

    func testBoundedFleetingNotesFetchLimitFallsBackToMinimumForNonPositiveValues() {
        XCTAssertEqual(FleetingNotesQueryPolicy.boundedFetchLimit(0), 1)
        XCTAssertEqual(FleetingNotesQueryPolicy.boundedFetchLimit(-5), 1)
    }

    func testBoundedFleetingNotesFetchLimitCapsLargeRequests() {
        XCTAssertEqual(
            FleetingNotesQueryPolicy.boundedFetchLimit(FleetingNotesQueryPolicy.maxFetchLimit + 50),
            FleetingNotesQueryPolicy.maxFetchLimit
        )
    }
}
