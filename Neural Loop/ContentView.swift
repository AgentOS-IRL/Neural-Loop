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
        ZStack {

            VStack {
                Group {
                    switch selectedTab {
                        case .goals:
                        GoalView()
                    case .todo:
                        TodoView()
                    case .habits:
                        HabitView()
                    default:
                        Text("Other Tab").onAppear { logger.info("ContentView appeared!") }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                GlassTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 14)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
