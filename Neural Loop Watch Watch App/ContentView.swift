//
//  ContentView.swift
//  Neural Loop Watch Watch App
//
//  Created by Sanjeev Hayal on 23/01/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: WatchWorkoutStore
    
    var body: some View {
        NavigationStack {
            Group {
                if store.currentSnapshot != nil {
                    // Active workout: go directly to fitness
                    WatchFitnessView()
                } else {
                    // No workout: compact dashboard
                    WatchDashboardView()
                }
            }
        }
    }
}

struct WatchDashboardView: View {
    var body: some View {
        List {
            NavigationLink {
                WatchFitnessView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fitness")
                            .font(.headline)
                        Text("Start on iPhone")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Neural Loop")
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchWorkoutStore.shared)
}
