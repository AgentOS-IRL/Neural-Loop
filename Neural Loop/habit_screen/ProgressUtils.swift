//
//  ProgressUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 19/01/2026.
//
import Foundation


struct HabitProgress {
    let current: Int
    let target: Int
    let targetLabel: String
    let window: HabitWindow

    var ratio: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
}

struct HabitWindow {
    let start: Date
    let end: Date
    let label: String
    let frequency: Calendar.RecurrenceRule.Frequency
    
    static func isOccurring(on date: Date, habit: Habits) -> Bool {
        guard let ruleString = habit.target_recursion_rule,
              !ruleString.isEmpty,
              let rule = try? parse_rrule(rruleString: ruleString),
              let anchor = habit.created_at else {
            return true
        }

        let cal = Calendar.neuralLoopDisplay
        let start = cal.startOfDay(for: date)
        let end = cal.endOfDay(date)
        
        return hasOccurrence(of: rule, between: start, and: end, anchor: anchor)
    }
    
    static func get_frequency(for habit: Habits) -> Calendar.RecurrenceRule.Frequency {
        guard
            let ruleString = habit.target_recursion_rule,
            let rule = try? parse_rrule(rruleString: ruleString)
        else {
            return Calendar.RecurrenceRule.Frequency.daily
        }
        return rule.frequency
        
    }

    static func window(for habit: Habits, reference: Date) -> HabitWindow {
        let frequency = HabitWindow.get_frequency(for: habit)

        switch frequency {
        case .daily:
            return _day(reference)
        case .weekly:
            return _week(reference)
        case .monthly:
            return _month(reference)
        default:
            return _day(reference)
        }
    }

    private static func _day(_ date: Date) -> HabitWindow {
        let cal = Calendar.neuralLoopDisplay
        return HabitWindow(
            start: cal.startOfDay(for: date),
            end: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!,
            label: "Today",
            frequency: .daily
        )
    }
    
    static func longWindow(for date: Date) -> HabitWindow {
        return _week(date)
    }

    static func _week(_ date: Date) -> HabitWindow {
        var calendar = Calendar.neuralLoopDisplay
        calendar.firstWeekday = 2 // Monday

        let startOfDay = calendar.startOfDay(for: date)

        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
        )!

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        return HabitWindow(
            start: weekStart,
            end: weekEnd,
            label: "This Week",
            frequency: .weekly
        )
    }

    private static func _month(_ date: Date) -> HabitWindow {
        let cal = Calendar.neuralLoopDisplay
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        return HabitWindow(start: start, end: end, label: "This Month", frequency: .monthly)
    }
}
