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

    static let shared = UnifiedDataModel(autoStart: !isRunningUnderTests())
    
    let manager :DBManager
    private let secretsFetcher: any SecretsFetching
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
    @Published var secrets: [Secrets] = []
    @Published private(set) var secretsLoaded = false
    
    @Published var currentHabitProgressMap: [Int64: HabitProgress] = [:] {
        didSet {
            guard let progress = currentHabitProgressMap[WaterAutoScheduling.shared.habit_id] else {
                return
            }

            Task {
                await WaterAutoScheduling.shared.schedule_notification(
                    current: progress.current,
                    target: progress.target
                )
            }
        }
    }
    
    @Published var progressChartData: [Int64: [Int: Float]] = [:]
    @Published var trendsChartData: [Int64: [Calendar.RecurrenceRule.Frequency: [Date: Float]]] = [:]
    
    @Published var habitTrackingEntriesMap: [Int64: [HabitTracking]] = [:]{
        didSet {
            let changes = getKeyChangeSets(fromKeys: oldValue.keys, toKeys: habitTrackingEntriesMap.keys)

            

            for key in changes.removed {
                currentHabitProgressMap.removeValue(forKey: key)
                progressChartData.removeValue(forKey: key)
            }
            
            for key in changes.common {
                if oldValue[key]!.count != habitTrackingEntriesMap[key]!.count {
                    let habit = habits.first(where: { $0.id == key })!
                    loadCurrentHabitProgress(for: habit, entries: habitTrackingEntriesMap[key]!)
                    loadProgressChartData(for: habit, entries: habitTrackingEntriesMap[key]!)
                }
            }
            
            for key in changes.added {
                let habit = habits.first(where: { $0.id == key })!
                loadCurrentHabitProgress(for: habit, entries: habitTrackingEntriesMap[key]!)
                loadProgressChartData(for: habit, entries: habitTrackingEntriesMap[key]!)
            }
            
        }
    }
    
    init(
        manager: DBManager? = nil,
        secretsFetcher: (any SecretsFetching)? = nil,
        autoStart: Bool = true
    ) {
        let resolvedManager = manager ?? DBManager.newInstance()
        self.manager = resolvedManager
        self.secretsFetcher = secretsFetcher ?? resolvedManager
        self.calendar  = Calendar.current
        if autoStart {
            Task {
                await initialize(manager: self.manager)
                print("Done Initializing")
            }
        }
    }
    
    private func initialize(manager: DBManager ) async {
        
        do{
            try await manager.reloadHabitEntries()
        }
        catch {
            print("Error Reloading Habit Entries", error)
            fatalError("\(error)")
        }
        
        async let _goals = loadGoals(manager: manager)
        async let _tracking = loadGoalTracking(manager: manager)
        async let _habits = loadHabits(manager: manager)
        async let _lifeAreas = loadLifeAreas(manager: manager)
        async let _tags = loadTags(manager: manager)
        async let _tasks = loadTasks(manager: manager)
        async let _secrets = loadSecrets(fetcher: secretsFetcher)
        
        _ = await (
            _goals,
            _tracking,
            _habits,
            _lifeAreas,
            _tags,
            _tasks,
            _secrets
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

    func loadSecrets(fetcher: (any SecretsFetching)? = nil) async {
        defer {
            secretsLoaded = true
        }

        do {
            print("Loading Secrets")
            let source = fetcher ?? secretsFetcher
            let fetched = try await source.fetchAllSecrets()
            secrets = fetched
        } catch {
            print("error", error)
        }
    }

    var loadedSecretKeys: [String] {
        secrets.map(\.key).sorted()
    }

    var canUseAudioMode: Bool {
        secretsLoaded && secrets.containsSecretKey(codexAuthTokenSecretKey)
    }

    
    func updateHabitEntries(for habit: Habits) async {
        
        do{
            let window = HabitWindow.longWindow(for: .now)
            let entries = try await manager.fetchHabitEntries(
                forTask: habit.id!,
//                from: window.start,
//                to: window.end
            )
            print("got entries for habit: \(habit.id!) \(entries.count)")
            habitTrackingEntriesMap[habit.id!] = entries
        }
        catch{
            print("Error fetching entries for habit: \(habit.id!)")
        }
        
    }
    
    func loadCurrentHabitProgress(for habit: Habits, entries: [HabitTracking], reference: Date = .now) {
        let window = HabitWindow.window(for: habit, reference: reference)
        
        let filteredEntries = entries.filter {
            $0.entry_date > window.start && $0.entry_date < window.end
        }
        let total = filteredEntries.reduce(0) { $0 + $1.value }

        currentHabitProgressMap[habit.id!] = HabitProgress(
            current: total,
            target: Int(habit.target),
            targetLabel: habit.label ?? "Times",
            window: window
        )
    }
    
    func loadProgressChartData(for habit: Habits, entries: [HabitTracking], reference: Date = .now) {
        progressChartData[habit.id!] =  loadDailyProgressChartData(for: habit, entries: entries)
        
    }
    
    private func loadDailyProgressChartData(for habit: Habits, entries: [HabitTracking])  -> [Int: Float] {
        let calendar = Calendar.current
        let window = HabitWindow.longWindow(for: .now)


        let weekStart = calendar.startOfDay(for: window.start)

        // Pre-fill all days
        var result: [Int: Float] = Dictionary(
            uniqueKeysWithValues: (0...6).map { ($0, 0) }
        )

        for entry in entries {
            let entryDay = calendar.startOfDay(for: entry.entry_date)

            let daysFromMonday = calendar.dateComponents(
                [.day],
                from: weekStart,
                to: entryDay
            ).day ?? 0

            let key = daysFromMonday // <-- MONDAY = 0

            guard (0...6).contains(key) else { continue }

            result[key, default: 0] += Float(entry.value)
        }

        return result
    }

}
