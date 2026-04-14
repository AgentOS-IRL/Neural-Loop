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
    @AppStorage("isAudioMode") private var isAudioMode = false
    @State private var selectedTab: AppTab = .calendar

    var body: some View {
        ZStack {
            if isAudioMode {
                AudioModeView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                manualShell
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.26), value: isAudioMode)
        .onAppear {
            Task {
                await NotificationManager.shared.requestPermission()
            }
        }
    }

    @ViewBuilder
    private var manualShell: some View {
        Group {
            switch selectedTab {
            case .goals:
                GoalScreenView()
            case .todo:
                TodoView()
            case .habits:
                HabitView()
            case .calendar:
                CalendarDayView()
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
    }
}
