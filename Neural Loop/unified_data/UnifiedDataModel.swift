//
//  UnifiedDataModel.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 16/01/2026.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

private func getKeyChangeSets<K: Hashable>(
    fromKeys: some Collection<K>,
    toKeys: some Collection<K>
) -> (removed: Set<K>, added: Set<K>, common: Set<K>) {

    let fromSet = Set(fromKeys)
    let toSet   = Set(toKeys)

    let removed = fromSet.subtracting(toSet)
    let added   = toSet.subtracting(fromSet)
    let common  = fromSet.intersection(toSet)

    return (removed, added, common)
}

@MainActor
final class UnifiedDataModel: ObservableObject {

    static let shared = UnifiedDataModel()
    
    let manager :DBManager
    let calendar: Calendar
    
    var _shortTermTasksDataBucket: [DateBucket] = []
    
    var _longTermGoalsDateBucket: [DateBucket] = buildLongRangeDateBuckets()
    
    
    
    
    // Source of truth
    @Published var goals: [Goals] = []
    @Published var goalTracking: [GoalsTracking] = []
    
    @Published var habits: [Habits] = []{
        didSet {
            
            let changes = getKeyChangeSets(fromKeys: oldValue.map(\.id!), toKeys: habits.map(\.id!))

            
            for key in changes.removed {
                habitTrackingEntriesMap.removeValue(forKey: key)
            }
            
            
            for key in changes.added {
                Task {
                    print("updateHabitEntries for: \(key)")
                    await updateHabitEntries(for: habits.first(where: { $0.id == key })!)
                    
                    print(habitTrackingEntriesMap[
                        key]!.count)
                }
            }
            
        }}
    
    @Published var lifeAreas: [LifeAreas] = []{
        didSet{
            for area in lifeAreas {
                if !lifeAreaExpandedIds.contains(area.id!) {
                    lifeAreaExpandedIds.insert(area.id!)
                }
            }
        }
    }
    @Published var lifeAreaExpandedIds: Set<Int64> = []
    
    @Published var tags: [Tags] = []
    @Published var tasks: [Tasks] = []{
        didSet {
            _shortTermTasksDataBucket = []
        }
    }
    
    @Published var habitProgressMap: [Int64: HabitProgress] = [:]
    
    @Published var habitTrackingEntriesMap: [Int64: [HabitTracking]] = [:]{
        didSet {
            let changes = getKeyChangeSets(fromKeys: oldValue.keys, toKeys: habitTrackingEntriesMap.keys)

            

            for key in changes.removed {
                habitProgressMap.removeValue(forKey: key)
            }
            
            for key in changes.common {
                if oldValue[key]!.count != habitTrackingEntriesMap[key]!.count {
                    updateHabitProgress(for: habits.first(where: { $0.id == key })!, entries: habitTrackingEntriesMap[key]!)
                    
                }
            }
            
            for key in changes.added {
                
                updateHabitProgress(for: habits.first(where: { $0.id == key })!, entries: habitTrackingEntriesMap[key]!)
            }
            
        }
    }
    
    private init() {
        self.manager = DBManager.newInstance()
        self.calendar  = Calendar.current
        Task {
            await initialize(manager: self.manager)
            print("Done Initializing")
        }
        
    }
    
    private func initialize(manager: DBManager ) async {

        async let _goals = loadGoals(manager: manager)
        async let _tracking = loadGoalTracking(manager: manager)
        async let _habits = loadHabits(manager: manager)
        async let _lifeAreas = loadLifeAreas(manager: manager)
        async let _tags = loadTags(manager: manager)
        async let _tasks = loadTasks(manager: manager)
        
        _ = await (
            _goals,
            _tracking,
            _habits,
            _lifeAreas,
            _tags,
            _tasks
        )
    }

    func loadGoals(manager: DBManager) async {
        do {
            print("Loading Goals")
            let fetched = try await manager.fetchAllGoals()
            goals = fetched
        } catch {
            print("error", error)
        }
    }
    
    
    
    func loadTasks(manager: DBManager) async {
        do {
            print("Loading Tasks")
            
            let fetched = try await manager.fetchAllTasks()
            tasks = fetched
        } catch {
            print("error", error)
            
        }
    }
    
    func loadHabits(manager: DBManager) async {
        do {
            print("Loading Habits")
            let fetched = try await manager.fetchAllHabits()
            habits = fetched
        } catch {
            print("error", error)
        }
    }
    
    func loadGoalTracking(manager: DBManager) async {
        do {
            print("Loading Goal Tracking")
            let fetched = try await manager.fetchAllGoalsTracking()
            goalTracking = fetched
        } catch {
            print("error", error)
        }
    }


    func loadLifeAreas(manager: DBManager) async {
        do {
            print("Loading Life Areas")
            let fetched = try await manager.fetchAllLifeAreas()
            lifeAreas = fetched
        } catch {
            print("error", error)
        }
    }

    func loadTags(manager: DBManager) async {
        do {
            print("Loading Tags")
            let fetched = try await manager.fetchAllTags()
            tags = fetched
        } catch {
            print("error", error)
        }
    }

    
    func updateHabitEntries(for habit: Habits) async {
        
        do{
            let entries = try await manager.fetchHabitEntries(
                forTask: habit.id!,
//                from: window.start,
//                to: window.end
            )
            habitTrackingEntriesMap[habit.id!] = entries
        }
        catch{
            print("Error fetching entries for habit: \(habit.id!)")
        }
        
    }
    
    func updateHabitProgress(for habit: Habits, entries: [HabitTracking], reference: Date = .now) {
        let window = HabitWindow.window(for: habit, reference: reference)
        
        let filteredEntries = entries.filter {
            $0.entry_date > window.start && $0.entry_date < window.end
        }
        let total = filteredEntries.reduce(0) { $0 + $1.value }

        habitProgressMap[habit.id!] = HabitProgress(
            current: total,
            target: Int(habit.target),
            targetLabel: habit.label ?? "Times",
            windowLabel: window.label
        )
    }
    
}
