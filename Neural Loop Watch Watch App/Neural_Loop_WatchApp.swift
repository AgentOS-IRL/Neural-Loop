//
//  Neural_Loop_WatchApp.swift
//  Neural Loop Watch Watch App
//
//  Created by Sanjeev Hayal on 23/01/2026.
//

import SwiftUI

@main
struct Neural_Loop_Watch_Watch_AppApp: App {
    @StateObject private var workoutStore = WatchWorkoutStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutStore)
        }
    }
}
