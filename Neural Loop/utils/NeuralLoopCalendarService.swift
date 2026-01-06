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
        taskId: Int,
        title: String,
        timing: TaskTiming,
        notes: String? = nil
    ) throws {

        let calendar = try createNeuralLoopCalendar()

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = timing.start
        event.endDate = timing.start.addingTimeInterval(timing.duration)
        event.notes = notes
        event.url = URL(string: "neuralloop://task/\(taskId)")
        // TODO: Save to calendar
//        try eventStore.save(event, span: .thisEvent)
    }
    
    func addRecurringEvent(
        taskId: Int,
        title: String,
        timing: TaskTiming,
        recurrenceRule: Calendar.RecurrenceRule,
        notes: String? = nil
    ) throws {

        let calendar = try createNeuralLoopCalendar()

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = timing.start
        event.endDate = timing.start.addingTimeInterval(timing.duration)

        // Map weekday rules to EKRecurrenceDayOfWeek
        let ekDaysOfTheWeek: [EKRecurrenceDayOfWeek] = recurrenceRule.weekdays.map { weekday in
            switch weekday {
            case .every(let localeDay):
                let ekWeekday: EKWeekday = {
                    switch localeDay {
                    case .monday:    return .monday
                    case .tuesday:   return .tuesday
                    case .wednesday: return .wednesday
                    case .thursday:  return .thursday
                    case .friday:    return .friday
                    case .saturday:  return .saturday
                    case .sunday:    return .sunday
                    }
                }()
                return EKRecurrenceDayOfWeek(ekWeekday)

            case .nth(let n, let localeDay):
                let ekWeekday: EKWeekday = {
                    switch localeDay {
                    case .monday:    return .monday
                    case .tuesday:   return .tuesday
                    case .wednesday: return .wednesday
                    case .thursday:  return .thursday
                    case .friday:    return .friday
                    case .saturday:  return .saturday
                    case .sunday:    return .sunday
                    }
                }()
                return EKRecurrenceDayOfWeek(ekWeekday, weekNumber: n)
            }
        }
        
        // Build the end rule
        var ekEnd: EKRecurrenceEnd? = nil
        if recurrenceRule.end != .never {
            if recurrenceRule.end.occurrences != nil {
                ekEnd = EKRecurrenceEnd(
                    occurrenceCount: recurrenceRule.end.occurrences!
                )
            }
            else if recurrenceRule.end.date != nil {
                ekEnd = EKRecurrenceEnd(end: recurrenceRule.end.date!)
            }
        }
        
        let ekFrequency: EKRecurrenceFrequency
            switch recurrenceRule.frequency {
            case .daily:
                ekFrequency = .daily
            case .weekly:
                ekFrequency = .weekly
            case .monthly:
                ekFrequency = .monthly
            case .yearly:
                ekFrequency = .yearly
            @unknown default:
                fatalError("Unsupported recurrence frequency")
            }

      
        
        // Create the EKRecurrenceRule
        let ekRule = EKRecurrenceRule(
            recurrenceWith: ekFrequency,
            interval: recurrenceRule.interval,
            daysOfTheWeek: ekDaysOfTheWeek,
            daysOfTheMonth: recurrenceRule.daysOfTheMonth as [NSNumber],
            monthsOfTheYear: recurrenceRule.months.map { NSNumber(value: $0.index) },
            weeksOfTheYear: recurrenceRule.weeks as [NSNumber],
            daysOfTheYear: recurrenceRule.daysOfTheYear as [NSNumber],
            setPositions: recurrenceRule.setPositions as [NSNumber],
            end: ekEnd
        )

        event.recurrenceRules = [ekRule]  // compiler now has clear types

        event.url = URL(string: "neuralloop://task/\(taskId)")
        event.notes = notes

        print("📅 [TEST MODE] Recurring Event Preview")
        print("Title:", event.title ?? "nil")
        print("Start:", event.startDate)
        print("End:", event.endDate)
        print("Notes:", event.notes ?? "nil")
        print("URL:", event.url?.absoluteString ?? "nil")

        if let rules = event.recurrenceRules {
            for rule in rules {
                print("— Recurrence Rule —")
                print("Frequency:", rule.frequency)
                print("Interval:", rule.interval)
                print("Days of Week:", rule.daysOfTheWeek ?? [])
                print("Days of Month:", rule.daysOfTheMonth ?? [])
                print("Months of Year:", rule.monthsOfTheYear ?? [])
                print("Weeks of Year:", rule.weeksOfTheYear ?? [])
                print("Days of Year:", rule.daysOfTheYear ?? [])
                print("Set Positions:", rule.setPositions ?? [])
                print("End:", rule.recurrenceEnd?.description ?? "never")
            }
        } else {
            print("No recurrence rules")
        }
        // TODO: Save to calendar
//         try eventStore.save(event, span: .thisEvent)
        print("Saved to Calendar")
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

