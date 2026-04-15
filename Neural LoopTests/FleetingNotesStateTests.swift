import XCTest
@testable import Neural_Loop

final class FleetingNotesStateTests: XCTestCase {
    func testLoadedStateSortsCardsNewestFirstAndBuildsSummary() {
        let now = date("2026-04-15T21:00:00Z")
        let older = FleetingNote(id: 1, created_at: now.addingTimeInterval(-7_200), note: "Older thought")
        let newer = FleetingNote(id: 2, created_at: now.addingTimeInterval(-1_800), note: "Newer thought")

        let state = FleetingNotesStateMapper.makeLoadedState(
            notes: [older, newer],
            now: now,
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .content(let content) = state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.summary.eyebrow, "Captured moments")
        XCTAssertEqual(content.summary.title, "2 fleeting notes")
        XCTAssertEqual(content.summary.subtitle, "Latest thought: Today at 20:30")
        XCTAssertEqual(content.cards.map(\.id), [2, 1])
        XCTAssertEqual(content.cards.first?.note, "Newer thought")
    }

    func testLoadedStateReturnsEmptyWhenNoNotesExist() {
        let state = FleetingNotesStateMapper.makeLoadedState(
            notes: [],
            now: date("2026-04-15T21:00:00Z"),
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .empty(let summary) = state else {
            return XCTFail("Expected empty state")
        }

        XCTAssertEqual(summary.eyebrow, "Fresh capture")
        XCTAssertEqual(summary.title, "No fleeting notes yet")
    }

    func testRelativeTimestampFormatsTodayYesterdayAndOlderDates() {
        let now = date("2026-04-15T21:00:00Z")

        XCTAssertEqual(
            FleetingNotesStateMapper.relativeTimestamp(
                for: now.addingTimeInterval(-1_800),
                now: now,
                calendar: calendarUTC,
                locale: locale,
                timeZone: timeZoneUTC
            ),
            "Today at 20:30"
        )

        XCTAssertEqual(
            FleetingNotesStateMapper.relativeTimestamp(
                for: now.addingTimeInterval(-86_400),
                now: now,
                calendar: calendarUTC,
                locale: locale,
                timeZone: timeZoneUTC
            ),
            "Yesterday at 21:00"
        )

        XCTAssertEqual(
            FleetingNotesStateMapper.relativeTimestamp(
                for: now.addingTimeInterval(-172_800),
                now: now,
                calendar: calendarUTC,
                locale: locale,
                timeZone: timeZoneUTC
            ),
            "13 Apr"
        )
    }

    private var locale: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    private func date(_ isoString: String) -> Date {
        ISO8601DateFormatter().date(from: isoString)!
    }

    private var timeZoneUTC: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }

    private var calendarUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneUTC
        calendar.locale = locale
        return calendar
    }
}
