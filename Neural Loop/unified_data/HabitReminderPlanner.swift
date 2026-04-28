//
//  HabitReminderPlanner.swift
//  Neural Loop
//
//  Created by Codex on 28/04/2026.
//

import Foundation

struct HabitReminderPlan {
    let habitId: Int64
    let title: String
    let body: String
    let fireDate: Date
    let index: Int
}

struct HabitReminderPlanner {
    private let calendar: Calendar
    private let minimumGap: TimeInterval

    init(
        calendar: Calendar = .neuralLoopDisplay,
        minimumGap: TimeInterval = 20 * 60
    ) {
        self.calendar = calendar
        self.minimumGap = minimumGap
    }

    func plans(
        for habit: Habits,
        current: Int,
        target: Int,
        window: HabitWindow,
        now: Date
    ) -> [HabitReminderPlan] {
        guard let habitId = habit.id else { return [] }

        let remaining = max(target - current, 0)
        guard remaining > 0 else { return [] }

        let dates: [Date]
        switch window.frequency {
        case .daily:
            dates = Self.generateDailyReminderTimes(
                count: remaining,
                now: now,
                earliest: now.addingTimeInterval(minimumGap),
                latest: window.end.addingTimeInterval(-60 * 60),
                minimumGap: minimumGap
            )
        default:
            let candidate = nextWindowReminderDate(now: now, windowEnd: window.end)
            dates = candidate > now ? [candidate] : []
        }

        return dates.enumerated().map { index, fireDate in
            HabitReminderPlan(
                habitId: habitId,
                title: habit.title,
                body: habit.description ?? "Habit reminder",
                fireDate: fireDate,
                index: index
            )
        }
    }

    static func generateDailyReminderTimes(
        count: Int,
        now: Date,
        earliest: Date,
        latest: Date,
        minimumGap: TimeInterval
    ) -> [Date] {
        guard count > 0 else { return [] }

        let start = max(earliest, now.addingTimeInterval(minimumGap))
        let end = max(latest, start.addingTimeInterval(minimumGap))

        guard end > start else { return [start] }

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

    private func nextWindowReminderDate(now: Date, windowEnd: Date) -> Date {
        let postWorkTime = targetPostWorkTimeToday(now: now)
        let minimumDate = now.addingTimeInterval(minimumGap)
        let candidate = max(postWorkTime, minimumDate)

        if candidate < windowEnd {
            return candidate
        }

        let fallback = windowEnd.addingTimeInterval(-60 * 60)
        return max(fallback, minimumDate)
    }

    private func targetPostWorkTimeToday(now: Date) -> Date {
        let sixPM = calendar.date(
            bySettingHour: 18,
            minute: 0,
            second: 0,
            of: now
        ) ?? now

        if now > sixPM {
            return calendar.date(byAdding: .minute, value: 20, to: now) ?? now
        }

        return sixPM
    }
}

