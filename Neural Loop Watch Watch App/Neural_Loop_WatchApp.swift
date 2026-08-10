//
//  Neural_Loop_WatchApp.swift
//  Neural Loop Watch Watch App
//
//  Created by Sanjeev Hayal on 23/01/2026.
//

import SwiftUI

@main
struct Neural_Loop_Watch_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workoutStore = WatchWorkoutStore()
    @StateObject private var dailyLoopStore = WatchDailyLoopStore()
    @StateObject private var launchRouter = WatchLaunchRouter()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutStore)
                .environmentObject(dailyLoopStore)
                .environmentObject(launchRouter)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        launchRouter.consumePendingRoute()
                    }
                }
        }
    }
}
