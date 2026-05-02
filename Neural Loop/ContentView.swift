//
//  ContentView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//


import SwiftUI
import OSLog

let logger = Logger(subsystem: "NeuralLoop", category: "App")

struct ContentView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        manualShell
        .onAppear {
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
            case .ai:
                AudioModeView()
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
            LiquidGlassTabBar(selectedTab: $selectedTab)
                .ignoresSafeArea(.container, edges: .bottom)
                .padding(.bottom, -20)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UnifiedDataModel(autoStart: false))
    }
}
