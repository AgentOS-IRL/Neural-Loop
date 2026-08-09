import SwiftUI

struct WatchDailyLoopView: View {
    @EnvironmentObject private var store: WatchDailyLoopStore

    var body: some View {
        List {
            if store.pendingCount > 0 || store.lastErrorMessage != nil {
                syncSection
            }

            if let snapshot = store.snapshot {
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

    private var syncSection: some View {
        Section {
            if let message = store.lastErrorMessage {
                Button {
                    store.retryPending()
                } label: {
                    Label("Retry", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                }
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                Label(
                    store.isReachable ? "Saving \(store.pendingCount)…" : "\(store.pendingCount) queued",
                    systemImage: store.isReachable ? "arrow.triangle.2.circlepath" : "iphone.slash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func taskSection(_ tasks: [DailyLoopWatchTaskSummary]) -> some View {
        Section("Tasks") {
            if tasks.isEmpty {
                Label("Nothing due", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    Button {
                        store.setTask(task, completed: !task.isCompleted)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? .green : .blue)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.body)
                                    .lineLimit(2)
                                    .strikethrough(task.isCompleted)

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

                                    if store.isTaskPending(task.identity) {
                                        Image(systemName: "clock")
                                            .accessibilityLabel("Queued")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(task.title), \(task.isCompleted ? "completed" : "not completed")")
                    .accessibilityHint(task.isCompleted ? "Reopens task" : "Completes task")
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
                    NavigationLink {
                        WatchHabitActionView(habitID: habit.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: habitSymbol(for: habit))
                                .foregroundStyle(habitColor(for: habit))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(habit.title)
                                    .font(.body)
                                    .lineLimit(2)

                                HStack(spacing: 4) {
                                    Text(habitProgressText(habit))
                                    if store.isHabitPending(habit.id) {
                                        Image(systemName: "clock")
                                            .accessibilityLabel("Queued")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
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

private struct WatchHabitActionView: View {
    @EnvironmentObject private var store: WatchDailyLoopStore
    let habitID: Int64

    private var habit: DailyLoopWatchHabitSummary? {
        store.snapshot?.habits.first { $0.id == habitID }
    }

    var body: some View {
        Group {
            if let habit {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(habit.title)
                                .font(.headline)
                                .lineLimit(2)
                            ProgressView(value: habit.progress)
                            Text(progressText(habit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        store.incrementHabit(habit)
                    } label: {
                        Label("Add 1", systemImage: "plus.circle.fill")
                    }
                    .disabled(habit.isSkipped)

                    Button {
                        store.setHabit(habit, skipped: !habit.isSkipped)
                    } label: {
                        Label(
                            habit.isSkipped ? "Unskip Today" : "Skip Today",
                            systemImage: habit.isSkipped ? "arrow.uturn.backward.circle" : "forward.circle"
                        )
                    }

                    if store.isHabitPending(habit.id) {
                        Label("Change queued", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView("Habit unavailable", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("Habit")
    }

    private func progressText(_ habit: DailyLoopWatchHabitSummary) -> String {
        let suffix = habit.label.flatMap { $0.isEmpty ? nil : " \($0)" } ?? ""
        return habit.isSkipped ? "Skipped today" : "\(habit.current) of \(habit.target)\(suffix)"
    }
}

struct WatchCaptureView: View {
    @EnvironmentObject private var store: WatchDailyLoopStore
    @State private var text = ""

    var body: some View {
        List {
            Section {
                TextField(
                    "What’s on your mind?",
                    text: $text,
                    prompt: Text("Tap to type or dictate")
                )
                .onSubmit(save)

                Button(action: save) {
                    Label("Save Note", systemImage: "arrow.up.circle.fill")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let status = store.captureStatus {
                Section("Latest") {
                    Label(statusTitle(status), systemImage: statusSymbol(status))
                        .foregroundStyle(statusColor(status))

                    Text(status.text)
                        .font(.caption)
                        .lineLimit(3)

                    if let message = status.message {
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if status.state == .failed {
                        Button("Retry") {
                            store.retryPending()
                        }
                    }
                }
            }

            Section {
                Button {
                    ConnectivityManager.shared.sendDeepLinkRequest(.addNote)
                } label: {
                    Label("Open iPhone Editor", systemImage: "iphone")
                }
            }
        }
        .navigationTitle("Capture")
    }

    private func save() {
        guard store.captureNote(text) else { return }
        text = ""
    }

    private func statusTitle(_ status: WatchCaptureStatus) -> String {
        switch status.state {
        case .queued: return "Queued"
        case .saved: return "Saved"
        case .failed: return "Failed"
        }
    }

    private func statusSymbol(_ status: WatchCaptureStatus) -> String {
        switch status.state {
        case .queued: return "clock"
        case .saved: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    private func statusColor(_ status: WatchCaptureStatus) -> Color {
        switch status.state {
        case .queued: return .orange
        case .saved: return .green
        case .failed: return .red
        }
    }
}
