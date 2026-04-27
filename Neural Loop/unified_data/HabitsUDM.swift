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
            let entry = try await manager.addHabitEntry(
                habitId: id,
                value: value,
                date: date
            )
            
            if habitTrackingEntriesMap[id] != nil {
                habitTrackingEntriesMap[id]!.append(entry)
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
            await notificationScheduler.clearHabitNotifications(habitId: id)
        } catch {
            print("Error deleting habit", error)
        }
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
        for window in timeWindows {
            
            let data = try await manager.fetchHabitEntries(
                forTask: id,
                from: window.0,
                to: window.1
            )
            
            let sum = data
                        .map { Int($0.value) }
                        .reduce(0, +)

            output[window.0] = Float(sum)
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
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isPast = cal.startOfDay(for: date) < cal.startOfDay(for: .now)

        for habit in habits {
            if !HabitWindow.isOccurring(on: date, habit: habit) { continue }
            
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
                let remaining = max(Int(habit.target) - currentProgress, 0)
                if remaining > 0 {
                    let frequency = HabitWindow.get_frequency(for: habit)
                    let nowAnchor = isToday ? Date() : cal.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date
                    
                    if frequency == .daily {
                        let earliest = nowAnchor.addingTimeInterval(20 * 60)
                        let latest = cal.endOfDay(date).addingTimeInterval(-60 * 60) // 11 PM
                        
                        let reminders = generatePlannedTimes(count: remaining, earliest: earliest, latest: latest, minimumGap: 20 * 60, nowAnchor: nowAnchor)
                        
                        for reminder in reminders {
                            events.append(SimpleEvent(
                                title: habit.title,
                                start: reminder,
                                end: reminder.addingTimeInterval(15 * 60),
                                acceptanceStatus: nil,
                                event_type: .habit
                            ))
                        }
                    } else {
                        // Weekly/Monthly - 6 PM
                        let sixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: date)!
                        let candidate = max(sixPM, nowAnchor.addingTimeInterval(20 * 60))
                        
                        if candidate < cal.endOfDay(date) {
                            events.append(SimpleEvent(
                                title: habit.title,
                                start: candidate,
                                end: candidate.addingTimeInterval(15 * 60),
                                acceptanceStatus: nil,
                                event_type: .habit
                            ))
                        }
                    }
                }
            }
        }
        
        return events
    }
    
    private func generatePlannedTimes(count: Int, earliest: Date, latest: Date, minimumGap: TimeInterval, nowAnchor: Date) -> [Date] {
        guard count > 0 else { return [] }
        let start = max(earliest, nowAnchor.addingTimeInterval(minimumGap))
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
}
