//
//  WorkoutLiveActivity.swift
//  Neural Loop Widgets
//
//  Created by Codex on 28/04/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            lockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.06, green: 0.06, blue: 0.08))
                .widgetURL(URL(string: "neural-loop://fitness/workout"))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.exerciseName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill")
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    setProgressLabel(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottomView(context: context)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.cyan)
            }
            .widgetURL(URL(string: "neural-loop://fitness/workout"))
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.cyan)
                Text(context.attributes.workoutTitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                progressBadge(context: context)
            }

            switch context.state.mode {
            case .resting:
                restingView(context: context)
            case .repEntry:
                repEntryView(context: context)
            case .finished:
                finishedView()
            }
        }
        .padding(16)
    }

    // MARK: - Rep Entry

    @ViewBuilder
    private func repEntryView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.exerciseName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("Set \(context.state.setNumber)/\(context.state.totalSets)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let reps = context.state.targetReps {
                        Text("· \(reps) reps")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let kg = context.state.weightKg {
                        Text("· \(kg)kg")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Circular set progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: setProgress(context: context))
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(context.state.completedReps ?? 0)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
        }
    }

    // MARK: - Resting

    @ViewBuilder
    private func restingView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rest")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)

                Text(context.state.exerciseName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            if let endDate = context.state.restEndDate {
                Text(timerInterval: Date.now...endDate, countsDown: true)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                    .frame(minWidth: 60)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Finished

    @ViewBuilder
    private func finishedView() -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Workout Complete")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.green)
            Spacer()
        }
    }

    // MARK: - Dynamic Island Helpers

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        switch context.state.mode {
        case .resting:
            if let endDate = context.state.restEndDate {
                Text(timerInterval: Date.now...endDate, countsDown: true)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                    .frame(minWidth: 40)
            }
        case .repEntry:
            Text("S\(context.state.setNumber)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.cyan)
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private func expandedBottomView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        switch context.state.mode {
        case .resting:
            restingView(context: context)
        case .repEntry:
            repEntryView(context: context)
        case .finished:
            finishedView()
        }
    }

    @ViewBuilder
    private func setProgressLabel(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        Text("Set \(context.state.setNumber)/\(context.state.totalSets)")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.cyan)
    }

    @ViewBuilder
    private func progressBadge(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        Text("\(Int(context.state.progress * 100))%")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.cyan.opacity(0.3)))
    }

    private func setProgress(context: ActivityViewContext<WorkoutActivityAttributes>) -> Double {
        guard context.state.totalSets > 0 else { return 0 }
        // setNumber is 1-indexed; (setNumber - 1) gives completed sets count
        return Double(context.state.setNumber - 1) / Double(context.state.totalSets)
    }
}
