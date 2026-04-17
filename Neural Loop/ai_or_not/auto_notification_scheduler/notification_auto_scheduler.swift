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

    init(
        scheduler: (any NotificationScheduling)? = nil,
        calendar: Calendar? = nil
    ) {
        self.scheduler = scheduler ?? NotificationManager.shared
        self.calendar = calendar ?? .neuralLoopDisplay
    }

    func scheduleAll(model: UnifiedDataModel, now: Date = .now) async {
        guard await scheduler.ensureAuthorizationStatus() else {
            return
        }

        await WaterAutoScheduling.shared.scheduleBaselineNotificationsIfAuthorized()
        await scheduleTasks(model.tasks, now: now)
        await scheduleHabits(
            model.habits,
            progress: model.currentHabitProgressMap,
            now: now
        )
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

        if habitId == WaterAutoScheduling.shared.habit_id {
            guard let progress else {
                await clearHabitNotifications(habitId: habitId)
                await scheduler.clearIndexedNotificationsAsync(prefix: "water_auto_")
                await scheduler.clearIndexedNotificationsAsync(prefix: "water.auto.")
                return
            }

            await WaterAutoScheduling.shared.schedule_notification(
                current: progress.current,
                target: progress.target
            )
            return
        }

        let prefix = habitPrefix + "\(habitId)"

        guard let progress else {
            await scheduler.clearIndexedNotificationsAsync(prefix: prefix)
            return
        }

        guard progress.current < progress.target else {
            await scheduler.clearIndexedNotificationsAsync(prefix: prefix)
            return
        }

        await scheduler.clearIndexedNotificationsAsync(prefix: prefix)

        let remaining = max(progress.target - progress.current, 0)
        guard remaining > 0 else { return }

        switch progress.window.frequency {
        case .daily:
            let reminders = habitReminderTimes(
                count: remaining,
                earliest: now.addingTimeInterval(20 * 60),
                latest: progress.window.end.addingTimeInterval(-60 * 60),
                minimumGap: 20 * 60
            )

            for (index, fireDate) in reminders.enumerated() {
                await scheduler.scheduleNotification(
                    id: "\(prefix).\(index)",
                    title: habit.title,
                    body: habit.description ?? "Habit reminder",
                    date: fireDate,
                    sound: .default,
                    userInfo: habitUserInfo(habitId: habitId, index: index)
                )
            }

        case .weekly, .monthly:
            let candidate = nextHabitWindowReminderDate(
                now: now,
                windowEnd: progress.window.end
            )

            guard candidate > now else { return }

            await scheduler.scheduleNotification(
                id: prefix + ".0",
                title: habit.title,
                body: habit.description ?? "Habit reminder",
                date: candidate,
                sound: .default,
                userInfo: habitUserInfo(habitId: habitId, index: 0)
            )

        default:
            let candidate = nextHabitWindowReminderDate(
                now: now,
                windowEnd: progress.window.end
            )

            guard candidate > now else { return }

            await scheduler.scheduleNotification(
                id: prefix + ".0",
                title: habit.title,
                body: habit.description ?? "Habit reminder",
                date: candidate,
                sound: .default,
                userInfo: habitUserInfo(habitId: habitId, index: 0)
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

    private func habitReminderTimes(
        count: Int,
        earliest: Date,
        latest: Date,
        minimumGap: TimeInterval
    ) -> [Date] {
        guard count > 0 else { return [] }

        let start = max(earliest, Date().addingTimeInterval(minimumGap))
        let end = max(latest, start.addingTimeInterval(minimumGap))

        guard end > start else { return [start] }

        let totalDuration = end.timeIntervalSince(start)
        if count == 1 {
            return [start]
        }

        var candidates: [Date] = []
        for index in 0..<count {
            let progress = Double(index + 1) / Double(count + 1)
            candidates.append(start.addingTimeInterval(totalDuration * progress))
        }

        var filtered: [Date] = []
        for candidate in candidates {
            if filtered.isEmpty {
                filtered.append(candidate)
                continue
            }

            guard candidate.timeIntervalSince(filtered.last!) >= minimumGap else { continue }
            filtered.append(candidate)
        }

        return filtered
    }

    private func nextHabitWindowReminderDate(now: Date, windowEnd: Date) -> Date {
        let postWorkTime = HabitAutoScheduler.shared.targetPostWorkTimeToday()
        let minimumDate = now.addingTimeInterval(20 * 60)
        let candidate = max(postWorkTime, minimumDate)

        if candidate < windowEnd {
            return candidate
        }

        let fallback = windowEnd.addingTimeInterval(-60 * 60)
        return max(fallback, minimumDate)
    }
}
