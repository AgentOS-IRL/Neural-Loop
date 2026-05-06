//
//  HabitsUDM.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 16/01/2026.
//


import Foundation
import SwiftUI
import SwiftData
import Combine


extension  UnifiedDataModel {
    
    func getHabits(goalId: Int64) -> [Habits] {
        return habits.filter { $0.goal_id == goalId }
    }
    
    func getHabits(lifeAreaId: Int64) -> [Habits] {
        return habits.filter { $0.lifearea_id == lifeAreaId }
    }
    
    
    func fetchHabitTrackingEntries(by habitId: Int64, window: HabitWindow) async -> [HabitTracking]{
        do {
            return try await manager.fetchHabitEntries(
                forTask: habitId,
                from: window.start,
                to: window.end
            )
        }
        catch {
            print("Error fetching habit entries: \(error)")
            return []
        }
        
    }
    
    
    func incrementHabit(_ habit: Habits, value: Int = 1, date: Date = Date()) async {
        guard let id = habit.id else { return }
        do {
            HabitSkipPersistenceManager.shared.unskipHabitToday(habitId: id)

            let window = HabitWindow.window(for: habit, reference: date)
            let result = try await manager.addHabitEntryWithSummary(
                habitId: id,
                value: value,
                date: date,
                windowStart: window.start,
                windowEnd: window.end
            )
            
            if habitTrackingEntriesMap[id] != nil {
                habitTrackingEntriesMap[id]!.append(result.entry)
            } else {
                habitTrackingEntriesMap[id] = [result.entry]
            }

            await notificationScheduler.scheduleHabit(
                habit,
                progress: currentHabitProgressMap[id]
            )
            
        } catch {
            print("Error adding entry for habit: \(habit.id!)")
        }
    }
    
    func saveNewHabit(_ habit: Habits) async {
        do {
            
            let newHabit = try await manager.addHabit(habit)
            habits.append(newHabit)
            await refreshHabitNotifications(for: newHabit)
        } catch {
            print("Error saving new habit", error, habit)
        }
    }
    
    func updateHabit(_ habit: Habits) async {
        do {
            try await manager.updateHabit(habit)
            let index = self.habits.firstIndex(where: { $0.id == habit.id! })!
            habits.remove(at: index)
            habits.append(habit)
            await refreshHabitNotifications(for: habit)
        } catch {
            print("Error updating habit", error)
        }
    }
    
    func deleteHabit(_ habit: Habits) async {
        guard let id = habit.id else { return }
        do {
            try await manager.deleteHabit(id: id)
            let index = self.habits.firstIndex(where: { $0.id == habit.id! })!
            habits.remove(at: index)
            HabitSkipPersistenceManager.shared.clearHabit(habitId: id)
            await notificationScheduler.clearHabitNotifications(habitId: id)
        } catch {
            print("Error deleting habit", error)
        }
    }

    func isHabitSkippedToday(_ habit: Habits) -> Bool {
        guard let id = habit.id else { return false }
        return HabitSkipPersistenceManager.shared.isHabitSkippedToday(habitId: id)
    }
    
    func unskipHabitToday(_ habit: Habits) async{
        guard let id = habit.id else {return}
        HabitSkipPersistenceManager.shared.unskipHabitToday(habitId: id)
        refreshWidgetSnapshot()
        await refreshHabitNotifications(for: habit)
        
    }

    func skipHabitToday(_ habit: Habits) async {
        guard let id = habit.id else { return }
        HabitSkipPersistenceManager.shared.skipHabitToday(habitId: id)
        refreshWidgetSnapshot()
        await notificationScheduler.clearHabitNotifications(habitId: id)
    }
    
    func deleteHabitEntry(_ entry: HabitTracking) async {
        do {
            try await manager.deleteHabitEntry(id: entry.id!)
            habitTrackingEntriesMap[entry.habit_id]!.removeAll { $0.id == entry.id }
        } catch {
            print("Failed to delete habit entry")
        }
        
    }
    
    func deleteAllHabitEntires(habitId: Int64) async {
        do {
            try await manager.deleteHabitEntries(forTask: habitId)
            habitTrackingEntriesMap.removeValue(forKey: habitId)
        } catch {
            print("Failed to delete all entries for habit")
        }
        
    }
    
    func generateTrendsData(forHabitWithId id :Int64, frequency: Calendar.RecurrenceRule.Frequency) async throws -> [Date: Float] {
        let timeWindows = getTimeWindows(frequency:frequency)
        
        var output: [Date: Float] = [:]
        let totals = try await manager.fetchHabitWindowTotals(habitId: id, windows: timeWindows)
        for total in totals {
            output[total.window_start] = Float(total.total_value)
        }
            
        return output
    }
    
    
    func getTrendsData(forHabitWithId id: Int64, frequency: Calendar.RecurrenceRule.Frequency) async -> [Date: Float] {
        // Fast-path cache lookup
        if let cached = trendsChartData[id]?[frequency] {
            return cached
        }
        
        do {
            // Generate data
            let data = try await generateTrendsData(forHabitWithId: id, frequency: frequency)
            
            // Cache result
            trendsChartData[id, default: [:]][frequency] = data
            
            return data
        }
        catch {
            print("Error generating trends data")
            return [:]
        }
    }
    
    
    private func getTimeWindows(
        frequency: Calendar.RecurrenceRule.Frequency,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> [(Date, Date)] {

        var windows: [(Date, Date)] = []

        switch frequency {

        case .weekly:
            let startOfCurrentWeek =
                calendar.dateInterval(of: .weekOfYear, for: reference)!.start

            // 0️⃣ Partial current week (e.g. Monday → now)
            windows.append((startOfCurrentWeek, reference))

            // 1️⃣–4️⃣ Previous full weeks
            for i in 1...4 {
                let start = calendar.date(
                    byAdding: .weekOfYear,
                    value: -i,
                    to: startOfCurrentWeek
                )!

                let end = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: calendar.date(byAdding: .weekOfYear, value: -(i - 1), to: startOfCurrentWeek)!
                )!

                windows.append((start, end))
            }

        case .monthly:
            let startOfCurrentMonth =
                calendar.dateInterval(of: .month, for: reference)!.start

            // 0️⃣ Partial current month
            windows.append((startOfCurrentMonth, reference))

            // 1️⃣–4️⃣ Previous full months
            for i in 1...4 {
                let start = calendar.date(
                    byAdding: .month,
                    value: -i,
                    to: startOfCurrentMonth
                )!

                let end = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: calendar.date(byAdding: .month, value: -(i - 1), to: startOfCurrentMonth)!
                )!

                windows.append((start, end))
            }

        default:
            break
        }

        return windows
    }

    private func refreshHabitNotifications(for habit: Habits) async {
        await notificationScheduler.scheduleHabit(
            habit,
            progress: currentHabitProgressMap[habit.id ?? -1]
        )
    }

    func getHabitCalendarEvents(for date: Date) async -> [SimpleEvent] {
        var events: [SimpleEvent] = []
        let cal = Calendar.neuralLoopDisplay
        let isToday = cal.isDateInToday(date)
        let isPast = cal.startOfDay(for: date) < cal.startOfDay(for: .now)
        let reminderPlanner = HabitReminderPlanner(calendar: .neuralLoopDisplay)

        for habit in habits {
            if !HabitWindow.isOccurring(on: date, habit: habit) { continue }
            if let habitId = habit.id,
               HabitSkipPersistenceManager.shared.isHabitSkippedToday(habitId: habitId, date: date) {
                continue
            }
            
            // 1. Add actual tracking entries as historical events
            let window = HabitWindow.window(for: habit, reference: date)
            let entries = await fetchHabitTrackingEntries(by: habit.id ?? -1, window: window)
            
            let todaysEntries = entries.filter {
                $0.entry_date >= cal.startOfDay(for: date) && $0.entry_date <= cal.endOfDay(date)
            }
            
            var currentProgress = 0
            for entry in todaysEntries {
                currentProgress += entry.value
                // Create a 15 min block for the actual entry
                events.append(SimpleEvent(
                    title: "\(habit.title) (Done)",
                    start: entry.entry_date,
                    end: entry.entry_date.addingTimeInterval(15 * 60),
                    acceptanceStatus: nil,
                    event_type: .habit
                ))
            }
            
            // 2. Add future predicted reminders if not fully completed
            if !isPast {
                let nowAnchor = isToday ? Date() : cal.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date
                let plans = reminderPlanner.plans(
                    for: habit,
                    current: currentProgress,
                    target: Int(habit.target),
                    window: window,
                    now: nowAnchor
                )

                for plan in plans {
                    if plan.fireDate < cal.endOfDay(date) {
                        events.append(SimpleEvent(
                            title: plan.title,
                            start: plan.fireDate,
                            end: plan.fireDate.addingTimeInterval(15 * 60),
                            acceptanceStatus: nil,
                            event_type: .habit
                        ))
                    }
                }
            }
        }
        
        return events
    }
    

}

final class HabitSkipPersistenceManager {
    static let shared = HabitSkipPersistenceManager()

    private let defaults: UserDefaults
    private let storageKey = "habit.skip.dates"
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .neuralLoopDisplay
    ) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func skipHabitToday(habitId: Int64, date: Date = .now) {
        var skippedHabits = storedSkippedHabits()
        skippedHabits["\(habitId)"] = dayIdentifier(for: date)
        defaults.set(skippedHabits, forKey: storageKey)
    }

    func unskipHabitToday(habitId: Int64, date: Date = .now) {
        let key = "\(habitId)"
        var skippedHabits = storedSkippedHabits()

        guard skippedHabits[key] == dayIdentifier(for: date) else { return }
        skippedHabits.removeValue(forKey: key)
        defaults.set(skippedHabits, forKey: storageKey)
    }

    func isHabitSkippedToday(habitId: Int64, date: Date = .now) -> Bool {
        storedSkippedHabits()["\(habitId)"] == dayIdentifier(for: date)
    }

    func clearHabit(habitId: Int64) {
        var skippedHabits = storedSkippedHabits()
        skippedHabits.removeValue(forKey: "\(habitId)")
        defaults.set(skippedHabits, forKey: storageKey)
    }

    private func storedSkippedHabits() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }
}
