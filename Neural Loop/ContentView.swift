//
//  ContentView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//


import SwiftUI
import OSLog
import SwiftData

let logger = Logger(subsystem: "NeuralLoop", category: "App")

struct ContentView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @Query private var recurringCompletions: [CompletedRecurringTask]
    @State private var selectedTab: AppTab = .tasks
    @State private var isMoodMeterPresented = false

    var body: some View {
        manualShell
        .onAppear {
            DailyLoopWatchActionProcessor.shared.configure(
                model: model,
                modelContext: modelContext
            )
            model.updateDailyLoopRecurringCompletions(recurringCompletions)
            if !isRunningUnderTests() {
                Task {
                    _ = await NotificationManager.shared.requestPermission()
                    await model.scheduleNotifications()
                }
            }
            handlePendingDeepLink()
        }
        .onChange(of: deepLink.pendingDeepLink) { _, newValue in
            guard newValue != nil else { return }
            handlePendingDeepLink()
        }
        .onChange(of: recurringCompletionWatchKeys) { _, _ in
            model.updateDailyLoopRecurringCompletions(recurringCompletions)
        }
        .sheet(isPresented: $isMoodMeterPresented) {
            MoodMeterView()
                .environmentObject(model)
        }
    }

    private var recurringCompletionWatchKeys: [RecurringCompletionWatchKey] {
        recurringCompletions.map {
            RecurringCompletionWatchKey(
                taskID: $0.taskId,
                occurrenceStart: $0.occurrenceStart,
                completedAt: $0.completedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.taskID != rhs.taskID { return lhs.taskID < rhs.taskID }
            if lhs.occurrenceStart != rhs.occurrenceStart {
                return (lhs.occurrenceStart ?? .distantPast) < (rhs.occurrenceStart ?? .distantPast)
            }
            return lhs.completedAt < rhs.completedAt
        }
    }

    @MainActor
    private func handlePendingDeepLink() {
        guard let link = deepLink.pendingDeepLink else { return }
        switch link {
        case .aiListen:
            selectedTab = .ai
            deepLink.clearPendingNavigation()
        case .tasks:
            selectedTab = .tasks
            deepLink.clearPendingNavigation()
        case .habits:
            selectedTab = .tasks
        case .addTask, .addNote:
            selectedTab = .tasks
        case .calendar:
            selectedTab = .calendar
            deepLink.clearPendingNavigation()
        case .fitnessHome:
            selectedTab = .fitness
            deepLink.clearPendingNavigation()
        case .fitnessActiveWorkout:
            selectedTab = .fitness
            // FitnessView will observe pendingDeepLink and auto-present the active workout
        }
    }

    @ViewBuilder
    private var manualShell: some View {
        Group {
            switch selectedTab {
            case .goals:
                GoalScreenView()
            case .tasks:
                TaskHubView()
            case .maps:
                MapsView(store: model.mapsStore)
            case .ai:
                AIModeView()
            case .calendar:
                CalendarDayView()
            case .fitness:
                FitnessView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LiquidGlassTabBar(
                selectedTab: $selectedTab,
                onMoodMeterRequested: {
                    isMoodMeterPresented = true
                }
            )
                .ignoresSafeArea(.container, edges: .bottom)
                .padding(.bottom, -20)
        }
    }
}

private struct RecurringCompletionWatchKey: Hashable {
    let taskID: Int64
    let occurrenceStart: Date?
    let completedAt: Date
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UnifiedDataModel(autoStart: false))
    }
}
