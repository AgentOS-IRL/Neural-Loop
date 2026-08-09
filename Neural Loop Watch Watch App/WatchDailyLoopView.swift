import SwiftUI

struct WatchDailyLoopView: View {
    let snapshot: DailyLoopWatchSnapshot?

    var body: some View {
        List {
            if let snapshot {
                taskSection(snapshot.tasks)
                habitSection(snapshot.habits)

                Section {
                    Text("Updated \(snapshot.generatedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Daily Loop Yet",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Open Neural Loop on iPhone to sync today’s tasks and habits.")
                )
            }
        }
        .navigationTitle("Daily Loop")
    }

    @ViewBuilder
    private func taskSection(_ tasks: [DailyLoopWatchTaskSummary]) -> some View {
        Section("Tasks") {
            if tasks.isEmpty {
                Label("Nothing due", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.body)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            if let startDate = task.startDate {
                                Text(startDate, style: .time)
                            } else {
                                Text("Any time")
                            }

                            if task.isRecurring {
                                Image(systemName: "repeat")
                                    .accessibilityLabel("Recurring")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func habitSection(_ habits: [DailyLoopWatchHabitSummary]) -> some View {
        Section("Habits") {
            if habits.isEmpty {
                Label("No habits today", systemImage: "circle.dashed")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(habits) { habit in
                    HStack(spacing: 8) {
                        Image(systemName: habitSymbol(for: habit))
                            .foregroundStyle(habitColor(for: habit))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.title)
                                .font(.body)
                                .lineLimit(2)

                            Text(habitProgressText(habit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func habitSymbol(for habit: DailyLoopWatchHabitSummary) -> String {
        if habit.isSkipped { return "forward.circle" }
        if habit.isComplete { return "checkmark.circle.fill" }
        return "circle"
    }

    private func habitColor(for habit: DailyLoopWatchHabitSummary) -> Color {
        if habit.isSkipped { return .secondary }
        if habit.isComplete { return .green }
        return .blue
    }

    private func habitProgressText(_ habit: DailyLoopWatchHabitSummary) -> String {
        if habit.isSkipped { return "Skipped" }
        let value = "\(habit.current) of \(habit.target)"
        guard let label = habit.label, !label.isEmpty else { return value }
        return "\(value) \(label)"
    }
}
