//
//  habit_auto_scheduler.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 22/01/2026.
//

import Foundation


@MainActor
final class HabitAutoScheduler{
    static let shared: HabitAutoScheduler = HabitAutoScheduler()
    
    init() {}
    
    func scheduleHabit(_ habit: Habits, progress: HabitProgress?) async {
        await NotificationAutoScheduler.shared.scheduleHabit(habit, progress: progress)
    }
    
    func targetPostWorkTimeToday() -> Date {
        let now = Date()
        let calendar = Calendar.current

        // Today at 6:00 PM
        let sixPM = calendar.date(
            bySettingHour: 18,
            minute: 0,
            second: 0,
            of: now
        )!

        // If now > 6 PM → return now + 20 minutes
        if now > sixPM {
            return calendar.date(byAdding: .minute, value: 20, to: now)!
        }

        // Otherwise → today at 6 PM
        return sixPM
    }
    
}
