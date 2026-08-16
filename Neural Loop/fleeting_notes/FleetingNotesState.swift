//
//  FleetingNotesState.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import Foundation

enum FleetingNotesScreenState: Equatable {
    case loading
    case empty(FleetingNotesSummary)
    case content(FleetingNotesContent)
    case error(FleetingNotesErrorState)
}

struct FleetingNotesSummary: Equatable {
    let eyebrow: String
    let title: String
    let subtitle: String
}

struct FleetingNotesContent: Equatable {
    let summary: FleetingNotesSummary
    let selectedFilter: FleetingNotesFilter
    let availableFilters: [FleetingNotesFilter]
    let cards: [FleetingNoteCardState]
    let workWarning: String?
}

struct FleetingNoteCardState: Identifiable, Equatable {
    let id: String
    let source: FleetingNoteSource
    let rawPersonalID: Int64?
    let rawWorkID: String?
    let workNotes: String?
    let note: String
    let timestamp: String
    let relativeTimestamp: String
    let badgeText: String
    let sourceSubtitle: String
    let linkedTaskID: Int64?
    let linkedTaskTitle: String?

    init(
        id: String,
        source: FleetingNoteSource,
        rawPersonalID: Int64?,
        rawWorkID: String?,
        workNotes: String?,
        note: String,
        timestamp: String,
        relativeTimestamp: String,
        badgeText: String,
        sourceSubtitle: String,
        linkedTaskID: Int64? = nil,
        linkedTaskTitle: String? = nil
    ) {
        self.id = id
        self.source = source
        self.rawPersonalID = rawPersonalID
        self.rawWorkID = rawWorkID
        self.workNotes = workNotes
        self.note = note
        self.timestamp = timestamp
        self.relativeTimestamp = relativeTimestamp
        self.badgeText = badgeText
        self.sourceSubtitle = sourceSubtitle
        self.linkedTaskID = linkedTaskID
        self.linkedTaskTitle = linkedTaskTitle
    }
}

enum FleetingNoteSource: String, Equatable, CaseIterable {
    case personal
    case work

    var displayName: String {
        switch self {
        case .personal:
            return "Personal"
        case .work:
            return "Work"
        }
    }
}

enum FleetingNotesFilter: String, Equatable, CaseIterable, Identifiable {
    case all
    case work
    case personal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .work:
            return "Work"
        case .personal:
            return "Personal"
        }
    }
}

struct UnifiedFleetingNote: Equatable {
    let source: FleetingNoteSource
    let stableID: String
    let text: String
    let createdAt: Date
    let personalNote: FleetingNote?
    let workReminder: WorkReminder?
}

struct FleetingNotesErrorState: Equatable {
    let title: String
    let message: String
}

enum FleetingNotesStateMapper {
    static func makeLoadedState(
        personalNotes: [FleetingNote],
        workReminders: [WorkReminder] = [],
        filter: FleetingNotesFilter = .all,
        workWarning: String? = nil,
        taskTitles: [Int64: String] = [:],
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> FleetingNotesScreenState {
        let unifiedNotes = makeUnifiedNotes(
            personalNotes: personalNotes,
            workReminders: workReminders
        )
        let filteredNotes = unifiedNotes.filter { note in
            switch filter {
            case .all:
                return true
            case .work:
                return note.source == .work
            case .personal:
                return note.source == .personal
            }
        }

        guard !filteredNotes.isEmpty else {
            return .empty(
                emptySummary(filter: filter, hasAnyNotes: !unifiedNotes.isEmpty)
            )
        }

        let cards = filteredNotes.map {
            FleetingNoteCardState(
                id: $0.stableID,
                source: $0.source,
                rawPersonalID: $0.personalNote?.id,
                rawWorkID: $0.workReminder?.id,
                workNotes: $0.workReminder?.notes,
                note: $0.text,
                timestamp: absoluteTimestamp(
                    for: $0.createdAt,
                    locale: locale,
                    timeZone: timeZone
                ),
                relativeTimestamp: relativeTimestamp(
                    for: $0.createdAt,
                    now: now,
                    calendar: calendar,
                    locale: locale,
                    timeZone: timeZone
                ),
                badgeText: $0.source.displayName,
                sourceSubtitle: sourceSubtitle(for: $0),
                linkedTaskID: $0.personalNote?.task_id,
                linkedTaskTitle: $0.personalNote?.task_id.flatMap { taskTitles[$0] }
            )
        }

        return .content(
            FleetingNotesContent(
                summary: contentSummary(cards: cards, filter: filter),
                selectedFilter: filter,
                availableFilters: FleetingNotesFilter.allCases,
                cards: cards,
                workWarning: workWarning
            )
        )
    }

    static func makeLoadedState(
        notes: [FleetingNote],
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> FleetingNotesScreenState {
        makeLoadedState(
            personalNotes: notes,
            workReminders: [],
            filter: .all,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    static func makeErrorState(_ error: Error) -> FleetingNotesScreenState {
        .error(
            FleetingNotesErrorState(
                title: "Unable to load notes",
                message: error.localizedDescription
            )
        )
    }

    static func absoluteTimestamp(
        for date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    static func relativeTimestamp(
        for date: Date,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var configuredCalendar = calendar
        configuredCalendar.locale = locale
        configuredCalendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        if configuredCalendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return "Today at \(formatter.string(from: date))"
        }

        if let yesterday = configuredCalendar.date(byAdding: .day, value: -1, to: now),
           configuredCalendar.isDate(date, inSameDayAs: yesterday) {
            formatter.dateFormat = "HH:mm"
            return "Yesterday at \(formatter.string(from: date))"
        }

        formatter.dateFormat = configuredCalendar.component(.year, from: date) == configuredCalendar.component(.year, from: now)
        ? "d MMM"
        : "d MMM yyyy"
        return formatter.string(from: date)
    }

    private static func makeUnifiedNotes(
        personalNotes: [FleetingNote],
        workReminders: [WorkReminder]
    ) -> [UnifiedFleetingNote] {
        let personal = personalNotes.map { note in
            UnifiedFleetingNote(
                source: .personal,
                stableID: "personal-\(note.id)",
                text: note.note,
                createdAt: note.created_at,
                personalNote: note,
                workReminder: nil
            )
        }

        let work = workReminders.map { reminder in
            UnifiedFleetingNote(
                source: .work,
                stableID: "work-\(reminder.id)",
                text: reminder.title,
                createdAt: reminder.createdAt,
                personalNote: nil,
                workReminder: reminder
            )
        }

        return (personal + work).sorted {
            if $0.createdAt == $1.createdAt {
                return $0.stableID > $1.stableID
            }

            return $0.createdAt > $1.createdAt
        }
    }

    private static func sourceSubtitle(for note: UnifiedFleetingNote) -> String {
        switch note.source {
        case .personal:
            return "Supabase"
        case .work:
            return note.workReminder?.calendarTitle ?? "Genesys"
        }
    }

    private static func emptySummary(filter: FleetingNotesFilter, hasAnyNotes: Bool) -> FleetingNotesSummary {
        switch filter {
        case .all:
            return FleetingNotesSummary(
                eyebrow: "Fresh capture",
                title: "No notes yet",
                subtitle: "Personal notes and Genesys work notes will appear here in reverse chronological order."
            )
        case .work:
            return FleetingNotesSummary(
                eyebrow: "Work notes",
                title: "No Genesys work notes",
                subtitle: hasAnyNotes ? "Switch to All or Personal to see other notes." : "Incomplete Genesys reminders will appear here as work notes."
            )
        case .personal:
            return FleetingNotesSummary(
                eyebrow: "Personal notes",
                title: "No personal notes",
                subtitle: hasAnyNotes ? "Switch to All or Work to see other notes." : "Personal Supabase note snippets will appear here."
            )
        }
    }

    private static func contentSummary(cards: [FleetingNoteCardState], filter: FleetingNotesFilter) -> FleetingNotesSummary {
        let count = cards.count
        let label: String
        let eyebrow: String

        switch filter {
        case .all:
            label = count == 1 ? "note" : "notes"
            eyebrow = "Captured moments"
        case .work:
            label = count == 1 ? "work note" : "work notes"
            eyebrow = "Work notes"
        case .personal:
            label = count == 1 ? "personal note" : "personal notes"
            eyebrow = "Personal notes"
        }

        return FleetingNotesSummary(
            eyebrow: eyebrow,
            title: "\(count) \(label)",
            subtitle: "Latest thought: \(cards.first?.relativeTimestamp ?? "just now")"
        )
    }
}
