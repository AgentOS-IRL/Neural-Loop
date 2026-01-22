//
//  habit_auto_scheduler.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 22/01/2026.
//

import Foundation
import EventKit


@MainActor
final class HabitAutoScheduler{
    static let shared: HabitAutoScheduler = HabitAutoScheduler()
    
    init() {printAllCalendarTitles()}
    
    func printAllCalendarTitles() {
        let eventStore = EKEventStore()

        eventStore.requestAccess(to: .event) { granted, error in
            guard granted else {
                print("❌ Calendar access denied")
                return
            }

            let calendars = eventStore.calendars(for: .event)

            print("📅 Found \(calendars.count) calendars:\n")

            for calendar in calendars {
                let sourceTitle = calendar.source.title
                let sourceType = calendar.source.sourceType

                print("""
                ────────────────
                Calendar: \(calendar.title)
                Source:   \(sourceTitle)
                Type:     \(sourceType)
                """)
            }
        }
    }
    
    func format_title(_ title: String) -> String {
        let prefix = title
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
        return prefix
    }
    
    func schedule_notification(title:String, current: Int, target: Int, frequency: Calendar.RecurrenceRule.Frequency) async {
        
        var requested = max(target - current, 0)
        
        guard requested > 0 else {
            print("🟡 [HabitAuthoScheduler] No remaining habit reminders needed")
            return
        }
        
        if frequency != .daily {
            requested = 1
        }
        
        var prefix = format_title(title) + "_auto_"
        
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
