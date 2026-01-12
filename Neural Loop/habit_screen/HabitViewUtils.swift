//
//  HabitViewUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 12/01/2026.
//
import Foundation
// MARK: - Supporting Models


func computeProgress(for habit: Habits, reference: Date = .now) async throws -> HabitProgress {
    let manager = DBManager.newInstance()
    
    let window = HabitWindow.window(for: habit, reference: reference)

    let entries = try await manager.fetchHabitEntries(
        forTask: habit.id!,
        from: window.start,
        to: window.end
    )

    let total = entries.reduce(0) { $0 + $1.value }
    let target = Int(habit.target)
    
    return HabitProgress(
        current: total,
        target: target,
        targetLabel: habit.label ?? "Times",
        windowLabel: window.label
    )
}

struct HabitProgress {
    let current: Int
    let target: Int
    let targetLabel: String
    let windowLabel: String

    var ratio: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
}

struct HabitWindow {
    let start: Date
    let end: Date
    let label: String

    static func window(for habit: Habits, reference: Date) -> HabitWindow {
        guard
            let ruleString = habit.target_recursion_rule,
            let rule = try? parse_rrule(rruleString: ruleString)
        else {
            return day(reference)
        }

        switch rule.frequency {
        case .daily:
            return day(reference)
        case .weekly:
            return week(reference)
        case .monthly:
            return month(reference)
        default:
            return day(reference)
        }
    }

    private static func day(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        return HabitWindow(
            start: cal.startOfDay(for: date),
            end: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!,
            label: "Today"
        )
    }

    private static func week(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return HabitWindow(start: start, end: end, label: "This Week")
    }

    private static func month(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        return HabitWindow(start: start, end: end, label: "This Month")
    }
}
