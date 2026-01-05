//
//  NeuralLoopCalendarService.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import EventKit

@MainActor
final class NeuralLoopCalendarService {

    static let shared = NeuralLoopCalendarService()
    private let eventStore = EKEventStore()

    private let calendarTitle = "Neural Loop"
    private var cachedCalendar: EKCalendar?

    // MARK: - Permission

    func requestAccess() async throws {
        try await eventStore.requestFullAccessToEvents()
    }

    // MARK: - Calendar Creation / Fetch

    func createNeuralLoopCalendar() throws -> EKCalendar {
        if let cachedCalendar {
            return cachedCalendar
        }

        if let existing = eventStore.calendars(for: .event)
            .first(where: { $0.title == calendarTitle }) {
            cachedCalendar = existing
            return existing
        }

        guard let iCloudSource = eventStore.sources.first(where: {
            $0.sourceType == .calDAV &&
            $0.title.lowercased().contains("icloud")
        }) else {
            throw CalendarError.iCloudUnavailable
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.source = iCloudSource

        try eventStore.saveCalendar(calendar, commit: true)
        cachedCalendar = calendar
        return calendar
    }

    // MARK: - Add Event

    func addEvent(
        title: String,
        start: Date,
        end: Date,
        notes: String? = nil
    ) throws {

        let calendar = try createNeuralLoopCalendar()

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = notes

        try eventStore.save(event, span: .thisEvent)
    }
    
    func addRecurringEvent(
        taskId: Int,
        title: String,
        start: Date,
        duration: Double=15,
        recurrenceRule: EKRecurrenceRule,
        notes: String? = nil
    ) throws {

        let calendar = try createNeuralLoopCalendar()

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(60 * duration) // 15 min default
        event.recurrenceRules = [recurrenceRule]
        event.url = URL(string: "neuralloop://task/\(taskId)")
        event.notes = notes

        try eventStore.save(event, span: .thisEvent)
    }
    
    func fetchEvent(for taskId: Int) throws -> EKEvent? {
        let calendar = try createNeuralLoopCalendar()
        let today = Calendar.current.startOfDay(for: Date())

        let predicate = eventStore.predicateForEvents(
            withStart: today,
            end: Date.distantFuture,
            calendars: [calendar]
        )

        return eventStore.events(matching: predicate).first {
            $0.url?.absoluteString == "neuralloop://task/\(taskId)"
        }
    }
    
    func deleteFutureOccurrences(taskId: Int) throws {
        guard let event = try fetchEvent(for: taskId) else { return }

        try eventStore.remove(
            event,
            span: .futureEvents,
            commit: true
        )
    }

    // MARK: - Fetch Today Events

    func fetchEventsToday() throws -> [EKEvent] {
        let calendar = try createNeuralLoopCalendar()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: startOfDay
        )!

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: [calendar]
        )

        return eventStore.events(matching: predicate)
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud calendar source not available. Ensure iCloud is enabled."
        }
    }
}
