//
//  Neural_LoopApp.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//

import SwiftUI
import EventKit
import SwiftData

@main
struct Neural_LoopApp: App {
    
    init() {
        let eventStore = EKEventStore()

        Task {
            do {
                try await eventStore.requestFullAccessToEvents()
                let _ = try NeuralLoopCalendarService.shared.createNeuralLoopCalendar()
                print("Calendar access granted")
            } catch {
                print("Calendar access denied: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }.modelContainer(for: [
            CompletedRecurringTask.self
        ])
    }
}
