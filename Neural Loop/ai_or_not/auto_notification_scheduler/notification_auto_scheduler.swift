//
//  notification_auto_scheduler.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 17/04/2026.
//

import Foundation
import EventKit
import UserNotifications

@MainActor
final class NotificationAutoScheduler {

    static let shared = NotificationAutoScheduler()

    private let scheduler: any NotificationScheduling
    private let calendar: Calendar
    private let habitReminderPlanner: HabitReminderPlanner

    init(
        scheduler: (any NotificationScheduling)? = nil,
        calendar: Calendar? = nil
    ) {
        self.scheduler = scheduler ?? NotificationManager.shared
        self.calendar = calendar ?? .neuralLoopDisplay
        self.habitReminderPlanner = HabitReminderPlanner(calendar: self.calendar)
    }

    func scheduleAll(model: UnifiedDataModel, now: Date = .now) async {
        guard await scheduler.ensureAuthorizationStatus() else {
            return
        }

        await scheduleTasks(model.tasks, now: now)
        await scheduleHabits(
            model.habits,
            progress: model.currentHabitProgressMap,
            now: now
        )
        await scheduleWork(now: now)
    }

    func scheduleWork(now: Date = .now) async {
        let events = await fetchGenesysEvents(for: now)
        await scheduleWorkEvents(events, now: now)
    }

    func scheduleTasks(_ tasks: [Tasks], now: Date = .now) async {
        await scheduler.clearIndexedNotificationsAsync(prefix: taskPrefix)

        for task in tasks {
            await scheduleTask(task, now: now)
        }
    }

    func scheduleTask(_ task: Tasks, now: Date = .now) async {
        guard let taskId = task.id else { return }

        await clearTaskNotifications(taskId: taskId)

        if task.is_completed, (task.recursion_rule == nil || task.recursion_rule?.isEmpty == true) {
            return
        }

        if let startDate = task.start_date {
            if let ruleString = task.recursion_rule,
               !ruleString.isEmpty,
               let rule = try? parse_rrule(rruleString: ruleString) {

                if startDate > now {
                    await scheduler.replaceNotification(
                        id: taskPrefix + "\(taskId)",
                        title: task.title,
                        body: task.description ?? "Scheduled task",
                        date: startDate,
                        sound: .default,
                        userInfo: taskUserInfo(taskId: taskId, occurrence: startDate)
                    )
                    return
                }

                if let next = nextOccurrence(of: rule, after: now), next > now {
                    await scheduler.replaceNotification(
                        id: occurrenceIdentifier(taskId: taskId, date: next),
                        title: task.title,
                        body: task.description ?? "Recurring task reminder",
                        date: next,
                        sound: .default,
                        userInfo: taskUserInfo(taskId: taskId, occurrence: next)
                    )
                }
                return
            }

            guard startDate > now else { return }
            await scheduler.replaceNotification(
                id: taskPrefix + "\(taskId)",
                title: task.title,
                body: task.description ?? "Task reminder",
                date: startDate,
                sound: .default,
                userInfo: taskUserInfo(taskId: taskId, occurrence: startDate)
            )
        }
    }

    func clearTaskNotifications(taskId: Int64) async {
        await scheduler.clearIndexedNotificationsAsync(prefix: taskPrefix + "\(taskId)")
    }

    func scheduleHabits(
        _ habits: [Habits],
        progress: [Int64: HabitProgress],
        now: Date = .now
    ) async {
        for habit in habits {
            await scheduleHabit(habit, progress: progress[habit.id ?? -1], now: now)
        }
    }

    func scheduleHabit(
        _ habit: Habits,
        progress: HabitProgress?,
        now: Date = .now
    ) async {
        guard let habitId = habit.id else { return }

        if HabitSkipPersistenceManager.shared.isHabitSkippedToday(habitId: habitId) {
            await clearHabitNotifications(habitId: habitId)
            return
        }

        guard let progress else {
            await clearHabitNotifications(habitId: habitId)
            return
        }

        let prefix = habitPrefix + "\(habitId)"

        guard progress.current < progress.target else {
            await clearHabitNotifications(habitId: habitId)
            return
        }

        await clearHabitNotifications(habitId: habitId)

        let plans = habitReminderPlanner.plans(
            for: habit,
            current: progress.current,
            target: progress.target,
            window: progress.window,
            now: now
        )

        for plan in plans {
            await scheduler.scheduleNotification(
                id: "\(prefix).\(plan.index)",
                title: plan.title,
                body: plan.body,
                date: plan.fireDate,
                sound: .default,
                userInfo: habitUserInfo(
                    habitId: plan.habitId,
                    index: plan.index
                )
            )
        }
    }

    func clearHabitNotifications(habitId: Int64) async {
        await scheduler.clearIndexedNotificationsAsync(prefix: habitPrefix + "\(habitId)")
    }

    func scheduleWorkEvents(_ events: [SimpleEvent], now: Date = .now) async {
        await scheduler.clearIndexedNotificationsAsync(prefix: workEventPrefix)

        for event in events where event.start > now {
            await scheduler.scheduleNotification(
                id: workEventIdentifier(for: event),
                title: event.title,
                body: "Your work event starts now",
                date: event.start,
                sound: .default,
                userInfo: [
                    "type": "work_event",
                    "title": event.title
                ]
            )
        }
    }

    func scheduleCalendarEvents(_ events: [EKEvent], now: Date = .now) async {
        await scheduler.clearIndexedNotificationsAsync(prefix: neuralLoopEventPrefix)

        for event in events {
            guard let startDate = event.startDate, startDate > now else { continue }

            await scheduler.scheduleNotification(
                id: neuralLoopEventIdentifier(for: event),
                title: event.title ?? "Neural Loop event",
                body: "Your calendar event starts now",
                date: startDate,
                sound: .default,
                userInfo: [
                    "type": "calendar_event",
                    "event_identifier": event.calendarItemIdentifier
                ]
            )
        }
    }

    // MARK: - Identifiers

    private var taskPrefix: String { "task." }
    private var habitPrefix: String { "habit." }
    private var workEventPrefix: String { "event.work." }
    private var neuralLoopEventPrefix: String { "event.neuralloop." }

    private func occurrenceIdentifier(taskId: Int64, date: Date) -> String {
        "\(taskPrefix)\(taskId).occurrence.\(dateIdentifier(date))"
    }

    private func workEventIdentifier(for event: SimpleEvent) -> String {
        "\(workEventPrefix)\(sanitize(event.title)).\(dateIdentifier(event.start))"
    }

    private func neuralLoopEventIdentifier(for event: EKEvent) -> String {
        "\(neuralLoopEventPrefix)\(sanitize(event.calendarItemIdentifier))"
    }

    private func dateIdentifier(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = NeuralLoopDateContext.locale
        formatter.timeZone = NeuralLoopDateContext.timeZone
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: date)
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return value
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private func taskUserInfo(taskId: Int64, occurrence: Date) -> [AnyHashable: Any] {
        [
            "type": "task",
            "task_id": taskId,
            "occurrence": occurrence.timeIntervalSinceReferenceDate
        ]
    }

    private func habitUserInfo(habitId: Int64, index: Int) -> [AnyHashable: Any] {
        [
            "type": "habit",
            "habit_id": habitId,
            "index": index
        ]
    }

}
