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
    @State private var selectedTab: AppTab = .habits

    var body: some View {
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
            default:
                Text("Other Tab")
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
