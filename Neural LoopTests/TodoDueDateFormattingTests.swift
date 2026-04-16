//
//  TodoDueDateFormattingTests.swift
//  Neural LoopTests
//
//  Created by Codex on 16/04/2026.
//

import XCTest
@testable import Neural_Loop

final class TodoDueDateFormattingTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    func testDueDateTextReturnsNoDueDateWhenStartIsNil() {
        let text = todoDueDateText(
            start: nil,
            duration: nil,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "no due date")
    }

    func testDueDateTextIncludesDateAndTimeWhenStartExistsWithoutDuration() {
        let text = normalized(todoDueDateText(
            start: date(year: 2026, month: 4, day: 16, hour: 9, minute: 30),
            duration: nil,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        ))

        XCTAssertNotEqual(text, "no due date")
        XCTAssertTrue(text.contains("Apr 16, 2026"), text)
        XCTAssertTrue(text.contains("9:30 AM"), text)
    }

    func testDueDateTextIncludesDateAndTimeRangeWhenDurationExists() {
        let text = normalized(todoDueDateText(
            start: date(year: 2026, month: 4, day: 16, hour: 9, minute: 30),
            duration: 900,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        ))

        XCTAssertTrue(text.contains("Apr 16, 2026"), text)
        XCTAssertTrue(text.contains("9:30 AM"), text)
        XCTAssertTrue(text.contains("9:45 AM"), text)
        XCTAssertTrue(text.contains(" - "), text)
    }

    func testDueDateTextIncludesEndDateWhenDurationCrossesMidnight() {
        let text = normalized(todoDueDateText(
            start: date(year: 2026, month: 4, day: 16, hour: 23, minute: 30),
            duration: 3_600,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        ))

        XCTAssertTrue(text.contains("Apr 16, 2026"), text)
        XCTAssertTrue(text.contains("11:30 PM"), text)
        XCTAssertTrue(text.contains("Apr 17, 2026"), text)
        XCTAssertTrue(text.contains("12:30 AM"), text)
    }

    func testDueDateTextTreatsNonPositiveDurationAsStartOnly() {
        let text = normalized(todoDueDateText(
            start: date(year: 2026, month: 4, day: 16, hour: 9, minute: 30),
            duration: 0,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        ))

        XCTAssertTrue(text.contains("Apr 16, 2026"), text)
        XCTAssertTrue(text.contains("9:30 AM"), text)
        XCTAssertFalse(text.contains(" - "), text)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
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

    private func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{202f}", with: " ")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
