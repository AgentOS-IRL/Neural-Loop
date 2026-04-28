//
//  CalendarUDM.swift
//  Neural Loop
//
//  Created by Codex on 28/04/2026.
//

import Foundation

extension UnifiedDataModel {
    func getCalendarEvents(for date: Date) async -> [SimpleEvent] {
        async let taskEvents = getTaskCalendarEvents(for: date)
        async let habitEvents = getHabitCalendarEvents(for: date)
        async let workEvents = getWorkCalendarEvents(for: date)

        return await workEvents + taskEvents + habitEvents
    }

    private func getTaskCalendarEvents(for date: Date) async -> [SimpleEvent] {
        let tasks = await getTasks(date: date)

        return tasks.compactMap { task in
            guard let startDate = task.start_date else { return nil }

            return SimpleEvent(
                title: task.title,
                start: startDate,
                end: startDate.addingTimeInterval(task.duration ?? 900),
                acceptanceStatus: nil,
                event_type: .task
            )
        }
    }

    private func getWorkCalendarEvents(for date: Date) async -> [SimpleEvent] {
        return await fetchGenesysEvents(for: date)
    }
}

