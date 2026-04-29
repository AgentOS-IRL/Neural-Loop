//
//  WorkoutComplicationWidget.swift
//  Neural Loop Watch Watch App
//
//  Created by Codex on 28/04/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WorkoutComplicationEntry: TimelineEntry {
    let date: Date
    let displayState: WorkoutDisplayState?
}

// MARK: - Timeline Provider

struct WorkoutComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutComplicationEntry {
        WorkoutComplicationEntry(date: .now, displayState: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutComplicationEntry) -> Void) {
        let state = loadDisplayState()
        completion(WorkoutComplicationEntry(date: .now, displayState: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutComplicationEntry>) -> Void) {
        let state = loadDisplayState()
        let entry = WorkoutComplicationEntry(date: .now, displayState: state)

        // If resting, schedule an update at rest end time
        var entries = [entry]
        if let restEnd = state?.restEndDate, restEnd > Date() {
            let postRestEntry = WorkoutComplicationEntry(date: restEnd, displayState: {
                var updated = state
                updated?.mode = .repEntry
                updated?.restEndDate = nil
                updated?.restTotalSeconds = nil
                return updated
            }())
            entries.append(postRestEntry)
        }

        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    private func loadDisplayState() -> WorkoutDisplayState? {
        guard let defaults = UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite),
              let data = defaults.data(forKey: WorkoutDisplayState.userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WorkoutDisplayState.self, from: data)
    }
}

// MARK: - Complication Views

struct WorkoutComplicationCircularView: View {
    let state: WorkoutDisplayState?

    var body: some View {
        if let state {
            ZStack {
                switch state.mode {
                case .resting:
                    if let endDate = state.restEndDate, endDate > Date() {
                        VStack(spacing: 1) {
                            Image(systemName: "timer")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                        }
                    } else {
                        Image(systemName: "timer")
                            .font(.title3)
                    }
                case .repEntry:
                    VStack(spacing: 1) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("S\(state.currentSetNumber)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                case .finished:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            }
        } else {
            ZStack {
                Image(systemName: "dumbbell")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WorkoutComplicationRectangularView: View {
    let state: WorkoutDisplayState?

    var body: some View {
        if let state {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption2)
                    Text(state.workoutTitle)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                }

                switch state.mode {
                case .resting:
                    HStack(spacing: 4) {
                        Text("Rest")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                        if let endDate = state.restEndDate, endDate > Date() {
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                case .repEntry:
                    HStack(spacing: 4) {
                        Text(state.currentExerciseName)
                            .font(.system(.caption2, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                        Text("Set \(state.currentSetNumber)/\(state.totalSets)")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                    }
                case .finished:
                    Text("Complete ✓")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.green)
                }

                // Progress gauge
                Gauge(value: state.exerciseProgress) {}
                    .gaugeStyle(.accessoryLinear)
                    .tint(.cyan)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell")
                        .font(.caption2)
                    Text("Neural Loop")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                Text("No active workout")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WorkoutComplicationInlineView: View {
    let state: WorkoutDisplayState?

    var body: some View {
        if let state {
            switch state.mode {
            case .resting:
                Label {
                    if let endDate = state.restEndDate, endDate > Date() {
                        Text("Rest \(Text(timerInterval: Date.now...endDate, countsDown: true))")
                    } else {
                        Text("Rest")
                    }
                } icon: {
                    Image(systemName: "timer")
                }
            case .repEntry:
                Label("\(state.currentExerciseName) S\(state.currentSetNumber)", systemImage: "dumbbell.fill")
            case .finished:
                Label("Workout Done", systemImage: "checkmark.circle.fill")
            }
        } else {
            Label("No Workout", systemImage: "dumbbell")
        }
    }
}

// MARK: - Complication Entry View (family-aware)

struct WorkoutComplicationEntryView: View {
    let entry: WorkoutComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                AccessoryWidgetBackground()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            WorkoutComplicationCircularView(state: entry.displayState)
        case .accessoryRectangular:
            WorkoutComplicationRectangularView(state: entry.displayState)
        case .accessoryInline:
            WorkoutComplicationInlineView(state: entry.displayState)
        default:
            WorkoutComplicationRectangularView(state: entry.displayState)
        }
    }
}

// MARK: - Widget Configuration

struct WorkoutComplicationWidget: Widget {
    let kind = "WorkoutComplicationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutComplicationProvider()) { entry in
            WorkoutComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Active Workout")
        .description("Shows your current workout exercise, set, and rest timer.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
