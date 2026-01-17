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
    
    func getHabit(by goalId: Int64) -> [Habits] {
        return habits.filter { $0.goal_id == goalId }
    }

    func getHabits(by lifeAreaId: Int64) -> [Habits] {
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
            habits[index] = habit
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
}
