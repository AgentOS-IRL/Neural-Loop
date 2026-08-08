//
//  CalendarUDM.swift
//  Neural Loop
//
//  Created by Codex on 28/04/2026.
//

import Foundation
import SwiftData

extension UnifiedDataModel {
    func getCalendarEvents(for date: Date, context: ModelContext) async -> [SimpleEvent] {
        let taskEvents = getTaskCalendarEvents(for: date, context: context)
        async let habitEvents = getHabitCalendarEvents(for: date)
        async let workEvents = getWorkCalendarEvents(for: date)

        return await workEvents + taskEvents + habitEvents
    }

    private func getTaskCalendarEvents(
        for date: Date,
        context: ModelContext
    ) -> [SimpleEvent] {
        let calendar = Calendar.neuralLoopDisplay
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return tasks.compactMap { task in
            guard let originalStart = task.start_date else { return nil }

            let isRecurring = task.recursion_rule?.isEmpty == false
            let occurrenceStart: Date
            let isCompleted: Bool

            if isRecurring {
                guard let recurringStart = recurringTaskOccurrenceStart(
                    for: task,
                    between: dayStart,
                    and: dayEnd
                ) else {
                    return nil
                }

                occurrenceStart = recurringStart
                isCompleted = task.id.map {
                    isRecurringTaskCompleted(
                        taskId: $0,
                        occurrenceStart: recurringStart,
                        context: context
                    )
                } ?? false
            } else {
                guard originalStart >= dayStart, originalStart < dayEnd else {
                    return nil
                }

                occurrenceStart = originalStart
                isCompleted = task.is_completed
            }

            return SimpleEvent(
                title: task.title,
                start: occurrenceStart,
                end: occurrenceStart.addingTimeInterval(task.duration ?? 900),
                acceptanceStatus: nil,
                event_type: .task,
                isCompleted: isCompleted
            )
        }
    }

    private func getWorkCalendarEvents(for date: Date) async -> [SimpleEvent] {
        return await fetchGenesysEvents(for: date)
    }
}
