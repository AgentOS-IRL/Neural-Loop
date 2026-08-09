//
//  ContentView.swift
//  Neural Loop Watch Watch App
//
//  Created by Sanjeev Hayal on 23/01/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: WatchWorkoutStore
    @EnvironmentObject var dailyLoopStore: WatchDailyLoopStore
    
    var body: some View {
        NavigationStack {
            Group {
                if store.currentSnapshot != nil {
                    // Active workout: go directly to fitness
                    WatchFitnessView()
                } else {
                    // No workout: compact dashboard
                    WatchDashboardView(snapshot: dailyLoopStore.snapshot)
                }
            }
        }
    }
}

struct WatchDashboardView: View {
    let snapshot: DailyLoopWatchSnapshot?

    var body: some View {
        List {
            Section {
                dailySummary
            }

            NavigationLink {
                WatchDailyLoopView()
            } label: {
                dashboardRoute(
                    title: "Daily Loop",
                    subtitle: "Tasks and habits",
                    symbol: "checklist",
                    color: .blue
                )
            }

            NavigationLink {
                WatchFitnessView()
            } label: {
                dashboardRoute(
                    title: "Workout",
                    subtitle: "Start on iPhone",
                    symbol: "figure.strengthtraining.traditional",
                    color: .green
                )
            }

            NavigationLink {
                WatchCaptureView()
            } label: {
                dashboardRoute(
                    title: "Capture",
                    subtitle: "Type or dictate",
                    symbol: "square.and.pencil",
                    color: .orange
                )
            }
        }
        .navigationTitle("Neural Loop")
    }

    @ViewBuilder
    private var dailySummary: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 7) {
                if let task = nextTask(in: snapshot) {
                    Text("NEXT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)

                    Text(task.title)
                        .font(.headline)
                        .lineLimit(2)

                    if let startDate = task.startDate {
                        Text(startDate, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("No tasks due", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                let remaining = remainingHabits(in: snapshot)
                Text("\(remaining) habit\(remaining == 1 ? "" : "s") remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isSummaryElement)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Loop")
                    .font(.headline)
                Text("Open iPhone to sync today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func dashboardRoute(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func nextTask(in snapshot: DailyLoopWatchSnapshot) -> DailyLoopWatchTaskSummary? {
        snapshot.tasks.first { !$0.isCompleted }
    }

    private func remainingHabits(in snapshot: DailyLoopWatchSnapshot) -> Int {
        snapshot.habits.filter { !$0.isComplete && !$0.isSkipped }.count
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchWorkoutStore.shared)
        .environmentObject(WatchDailyLoopStore())
}
