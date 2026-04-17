//
//  CalendarTimeAlignmentTests.swift
//  Neural LoopTests
//
//  Created by Codex on 17/04/2026.
//

import XCTest
@testable import Neural_Loop

final class CalendarTimeAlignmentTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")

    func testDateFormatterPreservesWallClockTimeInDstAwareTimezone() {
        let timeZone = TimeZone(identifier: "America/New_York")!
        let calendar = calendar(for: timeZone)
        let start = date(
            year: 2026,
            month: 6,
            day: 15,
            hour: 10,
            minute: 30,
            calendar: calendar,
            timeZone: timeZone
        )

        let text = normalized(todoDueDateText(
            start: start,
            duration: nil,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        ))

        XCTAssertTrue(text.contains("10:30 AM"), text)
        XCTAssertFalse(text.contains("9:30 AM"), text)
    }

    func testCalendarHelperExtractsWallClockComponentsInDstAwareTimezone() {
        let timeZone = TimeZone(identifier: "America/New_York")!
        let calendar = calendar(for: timeZone)
        let start = date(
            year: 2026,
            month: 6,
            day: 15,
            hour: 10,
            minute: 30,
            calendar: calendar,
            timeZone: timeZone
        )

        let components = calendar.neuralLoopDateComponents(from: start)

        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }

    private func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{202f}", with: " ")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
