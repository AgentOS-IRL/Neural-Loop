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
    let workReminderService: GenesysReminderService
    private let secretsFetcher: any SecretsFetching
    private let secretsUpdater: any SecretsUpdating
    private let codexTokenRefresher: any CodexTokenRefreshing
    let calendar: Calendar
    let notificationScheduler: NotificationAutoScheduler
    private var notificationRescheduleTask: Task<Void, Never>?
    private var codexTokenRefreshTask: Task<CodexCredentials?, Never>?
    
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

            scheduleNotificationRefresh()
            refreshWidgetSnapshot()
            
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
            scheduleNotificationRefresh()
            refreshWidgetSnapshot()
        }
    }
    @Published var secrets: [Secrets] = []
    @Published private(set) var secretsLoaded = false
    @Published private(set) var llmOverrideEnabled: Bool
    
    @Published var currentHabitProgressMap: [Int64: HabitProgress] = [:] {
        didSet {
            scheduleNotificationRefresh()
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

            scheduleNotificationRefresh()
            refreshWidgetSnapshot()
            
        }
    }
    
    init(
        manager: DBManager? = nil,
        secretsFetcher: (any SecretsFetching)? = nil,
        secretsUpdater: (any SecretsUpdating)? = nil,
        codexTokenRefresher: (any CodexTokenRefreshing)? = nil,
        autoStart: Bool = true,
        notificationScheduler: NotificationAutoScheduler? = nil,
        workReminderService: GenesysReminderService? = nil
    ) {
        let resolvedManager = manager ?? DBManager.newInstance()
        self.manager = resolvedManager
        self.workReminderService = workReminderService ?? GenesysReminderService()
        self.secretsFetcher = secretsFetcher ?? resolvedManager
        self.secretsUpdater = secretsUpdater ?? resolvedManager
        self.codexTokenRefresher = codexTokenRefresher ?? CodexTokenRefreshService()
        self.calendar  = Calendar.neuralLoopDisplay
        self.notificationScheduler = notificationScheduler ?? .shared
        self.llmOverrideEnabled = UserDefaults.standard.bool(forKey: llmEnabledOverrideStorageKey)
        if autoStart {
            Task {
                await initialize(manager: self.manager)
                print("Done Initializing")
            }
        }
    }
    
    private func initialize(manager: DBManager ) async {
        do {
            let lastID = try manager.localHabitTrackingStore.fetchLastHabitEntryId()
            let snapshot = try await manager.fetchAppBootstrapSnapshot(lastHabitTrackingId: lastID)
            
            try manager.localHabitTrackingStore.addMultiple(snapshot.habit_tracking_delta)
            
            self.lifeAreas = snapshot.life_areas
            self.goals = snapshot.goals
            self.goalTracking = snapshot.goals_tracking
            self.tags = snapshot.tags
            self.tasks = snapshot.tasks
            self.secrets = snapshot.secrets
            self.secretsLoaded = true
            _ = await refreshCodexTokenIfNeeded(force: false)
            
            self.habits = snapshot.habits
        } catch {
            print("Error initializing from snapshot:", error)
        }

        await scheduleNotifications()
    }

    func scheduleNotifications() async {
        await notificationScheduler.scheduleAll(model: self)
    }

    private func scheduleNotificationRefresh() {
        notificationRescheduleTask?.cancel()
        notificationRescheduleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.scheduleNotifications()
        }
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

    func loadSecrets(fetcher: (any SecretsFetching)? = nil, refreshCodexToken: Bool = true) async {
        defer {
            secretsLoaded = true
        }

        do {
            print("Loading Secrets")
            let source = fetcher ?? secretsFetcher
            let fetched = try await source.fetchAllSecrets()
            secrets = fetched
            if refreshCodexToken {
                _ = await refreshCodexTokenIfNeeded(force: false)
            }
        } catch {
            print("error", error)
        }
    }

    func refreshSecrets() async {
        await loadSecrets(refreshCodexToken: false)
        _ = await refreshCodexTokenIfNeeded(force: true)
    }

    var loadedSecretKeys: [String] {
        secrets.map(\.key).sorted()
    }

    var hasCodexAuthTokenSecret: Bool {
        secrets.containsSecretKey(codexAuthTokenSecretKey)
    }

    var hasChatGPTAccountIDSecret: Bool {
        secrets.containsSecretKey(chatgptAccountIDSecretKey)
    }

    var canUseAIMode: Bool {
        secretsLoaded && hasCodexAuthTokenSecret && hasChatGPTAccountIDSecret
    }

    var llm_enabled: Bool {
        shouldEnableLLMFeature(
            secretsLoaded: secretsLoaded,
            hasCodexAuthToken: hasCodexAuthTokenSecret,
            overrideEnabled: llmOverrideEnabled
        )
    }

    var codexAccessToken: String? {
        secrets.secretValue(for: codexAuthTokenSecretKey)
    }

    var codexAccountID: String? {
        secrets.secretValue(for: chatgptAccountIDSecretKey)
    }

    func validCodexCredentials() async -> CodexCredentials? {
        if shouldRefreshCodexToken() {
            return await refreshCodexTokenIfNeeded(force: false)
        }

        return currentCodexCredentials
    }

    private var currentCodexCredentials: CodexCredentials? {
        guard let accessToken = codexAccessToken,
              let accountID = codexAccountID else {
            return nil
        }

        return CodexCredentials(accessToken: accessToken, accountID: accountID)
    }

    private func shouldRefreshCodexToken() -> Bool {
        guard secrets.secretValue(for: codexRefreshTokenSecretKey) != nil else {
            return false
        }

        guard secrets.secretValue(for: codexAuthTokenSecretKey) != nil else {
            return true
        }

        guard let expiryValue = secrets.secretValue(for: codexTokenExpirySecretKey) else {
            return true
        }

        guard let expiryDate = Self.codexTokenExpiryFormatter.date(from: expiryValue) else {
            return true
        }

        return expiryDate <= Date().addingTimeInterval(60)
    }

    private func refreshCodexTokenIfNeeded(force: Bool) async -> CodexCredentials? {
        guard force || shouldRefreshCodexToken() else {
            return currentCodexCredentials
        }

        guard let refreshToken = secrets.secretValue(for: codexRefreshTokenSecretKey) else {
            return currentCodexCredentials
        }

        if let codexTokenRefreshTask {
            return await codexTokenRefreshTask.value
        }

        let task = Task<CodexCredentials?, Never> { @MainActor in
            await self.performCodexTokenRefresh(refreshToken: refreshToken)
        }
        codexTokenRefreshTask = task
        let credentials = await task.value
        codexTokenRefreshTask = nil

        return credentials ?? currentCodexCredentials
    }

    private func performCodexTokenRefresh(refreshToken: String) async -> CodexCredentials? {
        do {
            let response = try await codexTokenRefresher.refreshCodexToken(refreshToken: refreshToken)
            let expiryDate = Date().addingTimeInterval(response.expires_in)
            let expiryValue = Self.codexTokenExpiryFormatter.string(from: expiryDate)

            try await secretsUpdater.updateSecretValue(key: codexAuthTokenSecretKey, value: response.access_token)
            try await secretsUpdater.updateSecretValue(key: codexRefreshTokenSecretKey, value: response.refresh_token)
            try await secretsUpdater.updateSecretValue(key: codexTokenExpirySecretKey, value: expiryValue)

            secrets.updateSecretValue(response.access_token, for: codexAuthTokenSecretKey)
            secrets.updateSecretValue(response.refresh_token, for: codexRefreshTokenSecretKey)
            secrets.updateSecretValue(expiryValue, for: codexTokenExpirySecretKey)

            return currentCodexCredentials
        } catch {
            print("Error refreshing Codex token:", error)
            return nil
        }
    }

    private static let codexTokenExpiryFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func setLLMOverrideEnabled(_ enabled: Bool) {
        llmOverrideEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: llmEnabledOverrideStorageKey)
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
            habitTrackingEntriesMap[habit.id!] = entries.latestFirst()
        }
        catch{
            print("Error fetching entries for habit: \(habit.id!)")
        }
        
    }
    
    func loadCurrentHabitProgress(for habit: Habits, entries: [HabitTracking], reference: Date = .now) {
        if !HabitWindow.isOccurring(on: reference, habit: habit) {
            currentHabitProgressMap.removeValue(forKey: habit.id!)
            return
        }
        
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
        let calendar = Calendar.neuralLoopDisplay
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

extension UnifiedDataModel: AIModeCodexModel {}
