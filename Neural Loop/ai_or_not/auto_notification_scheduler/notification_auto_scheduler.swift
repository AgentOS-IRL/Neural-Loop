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

        let remaining = max(progress.target - progress.current, 0)
        guard remaining > 0 else { return }

        switch progress.window.frequency {
        case .daily:
            let useMealAnchors = (habitId == 1) // Water habit ID is 1
            let reminders = Self.generateDailyReminderTimes(
                count: remaining,
                now: now,
                earliest: now.addingTimeInterval(20 * 60),
                latest: progress.window.end.addingTimeInterval(-60 * 60),
                minimumGap: 20 * 60,
                useMealAnchors: useMealAnchors
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
        if habitId == 1 {
            await scheduler.clearIndexedNotificationsAsync(prefix: "water_auto_")
            await scheduler.clearIndexedNotificationsAsync(prefix: "water.auto.")
            if let customScheduler = scheduler as? NotificationManager {
                customScheduler.clearNotification(id: "repeat_water_auto")
                customScheduler.clearNotification(id: "water.daily")
            }
        }
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

    static func generateDailyReminderTimes(
        count: Int,
        now: Date,
        earliest: Date,
        latest: Date,
        minimumGap: TimeInterval,
        useMealAnchors: Bool
    ) -> [Date] {
        guard count > 0 else { return [] }

        let start = max(earliest, now.addingTimeInterval(minimumGap))
        let end = max(latest, start.addingTimeInterval(minimumGap))

        guard end > start else { return [start] }

        if !useMealAnchors {
            let totalDuration = end.timeIntervalSince(start)
            if count == 1 { return [start] }

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
                if candidate.timeIntervalSince(filtered.last!) >= minimumGap {
                    filtered.append(candidate)
                }
            }
            return filtered
        }

        // Meal anchor logic (originally from Water tracking)
        let calendar = Calendar.current
        func todayAt(_ hour: Int, _ minute: Int) -> Date? {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps)
        }

        var anchors: [Date] = []
        if let lunchTime = todayAt(13, 0), let dinnerTime = todayAt(21, 0) {
            let lunchAnchor = lunchTime.addingTimeInterval(-10 * 60)
            let dinnerAnchor = dinnerTime.addingTimeInterval(-10 * 60)
            
            func isValidAnchor(_ d: Date) -> Bool {
                return d > start && d < end
            }
            
            if count >= 1, now < lunchTime, isValidAnchor(lunchAnchor) {
                anchors.append(lunchAnchor)
            }
            if count >= 2, now < dinnerTime, isValidAnchor(dinnerAnchor) {
                anchors.append(dinnerAnchor)
            }
            if count == 1, anchors.count > 1 {
                anchors = [anchors[0]]
            }
        }
        
        let sortedAnchors = anchors.sorted()
        let points: [Date] = [start] + sortedAnchors + [end]
        
        var fillCount = count - sortedAnchors.count
        var segmentCounts: [Int] = []
        var segmentDurations: [TimeInterval] = []
        
        for i in 0..<(points.count - 1) {
            let a = points[i]
            let b = points[i + 1]
            segmentDurations.append(max(b.timeIntervalSince(a), 0))
        }
        
        let totalDur = segmentDurations.reduce(0, +)
        for dur in segmentDurations {
            if fillCount == 0 || totalDur <= 0 {
                segmentCounts.append(0)
                continue
            }
            segmentCounts.append(Int(round(Double(fillCount) * (dur / totalDur))))
        }
        
        // Fix rounding issues
        var sum = segmentCounts.reduce(0, +)
        while sum > fillCount {
            if let idx = segmentCounts.indices.max(by: { segmentCounts[$0] < segmentCounts[$1] }), segmentCounts[idx] > 0 {
                segmentCounts[idx] -= 1
                sum -= 1
            } else { break }
        }
        while sum < fillCount {
            if let idx = segmentCounts.indices.max(by: { segmentDurations[$0] < segmentDurations[$1] }) {
                segmentCounts[idx] += 1
                sum += 1
            } else { break }
        }
        
        // Cap by minGap
        for i in segmentCounts.indices {
            let maxInSegment = Int(floor(segmentDurations[i] / minimumGap))
            segmentCounts[i] = min(segmentCounts[i], maxInSegment)
        }
        fillCount = segmentCounts.reduce(0, +)
        
        var times: [Date] = []
        times.append(contentsOf: sortedAnchors)
        
        for i in 0..<(points.count - 1) {
            let segStart = points[i]
            let segEnd = points[i + 1]
            let c = segmentCounts[i]
            guard c > 0 else { continue }
            let dur = segEnd.timeIntervalSince(segStart)
            guard dur > 0 else { continue }
            
            for k in 0..<c {
                times.append(segStart.addingTimeInterval(dur * (Double(k + 1) / Double(c + 1))))
            }
        }
        
        times.sort()
        
        var finalTimes: [Date] = []
        for t in times {
            if finalTimes.isEmpty {
                if t > start { finalTimes.append(t) }
            } else {
                if t.timeIntervalSince(finalTimes.last!) >= minimumGap {
                    finalTimes.append(t)
                }
            }
            if finalTimes.count == count { break }
        }
        return finalTimes
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
