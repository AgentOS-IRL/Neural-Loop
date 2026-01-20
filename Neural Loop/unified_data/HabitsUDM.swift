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
            
        } catch {
            print("Error adding entry for habit: \(habit.id!)")
        }
    }
    
    func saveNewHabit(_ habit: Habits) async {
        do {
            
            let newHabit = try await manager.addHabit(habit)
            habits.append(newHabit)
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
}
