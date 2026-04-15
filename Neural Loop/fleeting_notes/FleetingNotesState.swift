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
    let cards: [FleetingNoteCardState]
}

struct FleetingNoteCardState: Identifiable, Equatable {
    let id: Int64
    let note: String
    let timestamp: String
    let relativeTimestamp: String
}

struct FleetingNotesErrorState: Equatable {
    let title: String
    let message: String
}

enum FleetingNotesStateMapper {
    static func makeLoadedState(
        notes: [FleetingNote],
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> FleetingNotesScreenState {
        let sortedNotes = FleetingNote.sortedNewestFirst(notes)

        guard !sortedNotes.isEmpty else {
            return .empty(
                FleetingNotesSummary(
                    eyebrow: "Fresh capture",
                    title: "No fleeting notes yet",
                    subtitle: "Once Supabase has note snippets, they will appear here in reverse chronological order."
                )
            )
        }

        let cards = sortedNotes.map {
            FleetingNoteCardState(
                id: $0.id,
                note: $0.note,
                timestamp: absoluteTimestamp(
                    for: $0.created_at,
                    locale: locale,
                    timeZone: timeZone
                ),
                relativeTimestamp: relativeTimestamp(
                    for: $0.created_at,
                    now: now,
                    calendar: calendar,
                    locale: locale,
                    timeZone: timeZone
                )
            )
        }

        return .content(
            FleetingNotesContent(
                summary: FleetingNotesSummary(
                    eyebrow: "Captured moments",
                    title: "\(cards.count) fleeting \(cards.count == 1 ? "note" : "notes")",
                    subtitle: "Latest thought: \(cards.first?.relativeTimestamp ?? "just now")"
                ),
                cards: cards
            )
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
}
