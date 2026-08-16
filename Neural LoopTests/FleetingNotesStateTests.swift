import XCTest
import SwiftUI
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
        XCTAssertEqual(content.summary.title, "2 notes")
        XCTAssertEqual(content.summary.subtitle, "Latest thought: Today at 20:30")
        XCTAssertEqual(content.cards.map(\.id), ["personal-2", "personal-1"])
        XCTAssertEqual(content.cards.first?.note, "Newer thought")
        XCTAssertEqual(content.cards.first?.source, .personal)
        XCTAssertEqual(content.cards.first?.badgeText, "Personal")
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
        XCTAssertEqual(summary.title, "No notes yet")
    }

    func testPersonalNoteMapsLinkedTaskChipState() {
        let now = date("2026-04-15T21:00:00Z")
        let note = FleetingNote(
            id: 1,
            created_at: now,
            note: "Task context",
            task_id: 42
        )

        let state = FleetingNotesStateMapper.makeLoadedState(
            personalNotes: [note],
            taskTitles: [42: "Ship task notes"],
            now: now,
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .content(let content) = state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.cards.first?.linkedTaskID, 42)
        XCTAssertEqual(content.cards.first?.linkedTaskTitle, "Ship task notes")
    }

    func testLoadedStateMergesPersonalAndWorkNotesNewestFirst() {
        let now = date("2026-04-15T21:00:00Z")
        let personal = FleetingNote(id: 1, created_at: now.addingTimeInterval(-7_200), note: "Personal thought")
        let work = WorkReminder(
            id: "abc",
            title: "Follow up with customer",
            notes: "Bring renewal details",
            createdAt: now.addingTimeInterval(-1_800),
            dueDate: nil,
            calendarTitle: "Reminders",
            sourceTitle: "Genesys"
        )

        let state = FleetingNotesStateMapper.makeLoadedState(
            personalNotes: [personal],
            workReminders: [work],
            filter: .all,
            now: now,
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .content(let content) = state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.cards.map(\.id), ["work-abc", "personal-1"])
        XCTAssertEqual(content.cards.map(\.source), [.work, .personal])
        XCTAssertEqual(content.cards.first?.badgeText, "Work")
        XCTAssertEqual(content.cards.first?.sourceSubtitle, "Reminders")
        XCTAssertEqual(content.cards.first?.workNotes, "Bring renewal details")
    }

    func testWorkFilterOnlyIncludesWorkNotes() {
        let now = date("2026-04-15T21:00:00Z")
        let personal = FleetingNote(id: 1, created_at: now, note: "Personal thought")
        let work = WorkReminder(
            id: "abc",
            title: "Follow up with customer",
            notes: nil,
            createdAt: now.addingTimeInterval(-1_800),
            dueDate: nil,
            calendarTitle: "Reminders",
            sourceTitle: "Genesys"
        )

        let state = FleetingNotesStateMapper.makeLoadedState(
            personalNotes: [personal],
            workReminders: [work],
            filter: .work,
            now: now,
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .content(let content) = state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.summary.title, "1 work note")
        XCTAssertEqual(content.cards.map(\.source), [.work])
    }

    func testPersonalFilterOnlyIncludesPersonalNotes() {
        let now = date("2026-04-15T21:00:00Z")
        let personal = FleetingNote(id: 1, created_at: now, note: "Personal thought")
        let work = WorkReminder(
            id: "abc",
            title: "Follow up with customer",
            notes: nil,
            createdAt: now.addingTimeInterval(-1_800),
            dueDate: nil,
            calendarTitle: "Reminders",
            sourceTitle: "Genesys"
        )

        let state = FleetingNotesStateMapper.makeLoadedState(
            personalNotes: [personal],
            workReminders: [work],
            filter: .personal,
            now: now,
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .content(let content) = state else {
            return XCTFail("Expected content state")
        }

        XCTAssertEqual(content.summary.title, "1 personal note")
        XCTAssertEqual(content.cards.map(\.source), [.personal])
    }

    func testWorkFilterEmptyStateIsSourceAware() {
        let state = FleetingNotesStateMapper.makeLoadedState(
            personalNotes: [
                FleetingNote(
                    id: 1,
                    created_at: date("2026-04-15T21:00:00Z"),
                    note: "Personal thought"
                )
            ],
            workReminders: [],
            filter: .work,
            now: date("2026-04-15T21:00:00Z"),
            calendar: calendarUTC,
            locale: locale,
            timeZone: timeZoneUTC
        )

        guard case .empty(let summary) = state else {
            return XCTFail("Expected empty state")
        }

        XCTAssertEqual(summary.eyebrow, "Work notes")
        XCTAssertEqual(summary.title, "No Genesys work notes")
        XCTAssertEqual(summary.subtitle, "Switch to All or Personal to see other notes.")
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

final class ThemeColorTests: XCTestCase {
    func testThemeColorsAreAccessible() {
        XCTAssertNotNil(FleetingNotesTheme.backgroundGradient)
        XCTAssertNotNil(FleetingNotesTheme.textPrimary)
        XCTAssertNotNil(FleetingNotesTheme.textSecondary)
        XCTAssertNotNil(FleetingNotesTheme.glowColor)
        XCTAssertNotNil(FleetingNotesTheme.accentGradient)
        
        let adaptive = Color.adaptive(light: .red, dark: .blue)
        XCTAssertNotNil(adaptive)
    }
}
