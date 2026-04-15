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
    @AppStorage("isAudioMode") private var isAudioMode = false
    @State private var selectedTab: AppTab = .calendar

    var body: some View {
        ZStack {
            if shouldPresentAudioModeShell {
                AudioModeView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                manualShell
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.26), value: shouldPresentAudioModeShell)
        .onAppear {
            reconcileAudioModePreference()
            if !isRunningUnderTests() {
                Task {
                    await NotificationManager.shared.requestPermission()
                }
            }
        }
        .onChange(of: model.secretsLoaded) { _, _ in
            reconcileAudioModePreference()
        }
        .onChange(of: model.canUseAudioMode) { _, _ in
            reconcileAudioModePreference()
        }
    }

    private var shouldPresentAudioModeShell: Bool {
        shouldShowAudioModeShell(
            isAudioModeEnabled: isAudioMode,
            canUseAudioMode: model.canUseAudioMode
        )
    }

    @ViewBuilder
    private var manualShell: some View {
        Group {
            switch selectedTab {
            case .goals:
                GoalScreenView()
            case .tasks:
                TaskHubView()
            case .notes:
                FleetingNotesView()
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

    private func reconcileAudioModePreference() {
        guard model.secretsLoaded else {
            return
        }

        guard !model.canUseAudioMode else {
            return
        }

        if isAudioMode {
            isAudioMode = false
        }
    }
}

func shouldShowAudioModeShell(
    isAudioModeEnabled: Bool,
    canUseAudioMode: Bool
) -> Bool {
    isAudioModeEnabled && canUseAudioMode
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UnifiedDataModel(autoStart: false))
    }
}
