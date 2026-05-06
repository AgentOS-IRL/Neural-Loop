//
//  NeuralLoopCalendarWidget.swift
//  Neural Loop Widgets
//
//  Created by Sanjeev Halyal on 04/05/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct NeuralLoopCalendarEntry: TimelineEntry {
    let date: Date
    let snapshot: NeuralLoopWidgetSnapshot
}

struct NeuralLoopCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> NeuralLoopCalendarEntry {
        NeuralLoopCalendarEntry(date: .now, snapshot: Self.previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (NeuralLoopCalendarEntry) -> Void) {
        completion(NeuralLoopCalendarEntry(date: .now, snapshot: snapshot(for: context)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NeuralLoopCalendarEntry>) -> Void) {
        let entry = NeuralLoopCalendarEntry(date: .now, snapshot: snapshot(for: context))
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func snapshot(for context: Context) -> NeuralLoopWidgetSnapshot {
        if context.isPreview {
            return Self.previewSnapshot
        }

        return NeuralLoopWidgetSnapshotStore.load() ?? NeuralLoopWidgetSnapshot(tasks: [], habits: [])
    }

    static let previewSnapshot = NeuralLoopWidgetSnapshot(
        tasks: [
            NeuralLoopWidgetTask(id: 1, title: "Plan launch tasks Plan launch tasks", startDate: .now.addingTimeInterval(45 * 60), duration: 30 * 60, priority: 3),
            NeuralLoopWidgetTask(id: 2, title: "Review inbox", startDate: nil, duration: nil, priority: 1),
            NeuralLoopWidgetTask(id: 3, title: "Write weekly note", startDate: .now.addingTimeInterval(4 * 60 * 60), duration: 45 * 60, priority: 2)
        ],
        habits: [
            NeuralLoopWidgetHabit(id: 1, title: "Deep work", current: 1, target: 2, label: "sessions", priority: 3, isSkippedToday: false),
            NeuralLoopWidgetHabit(id: 2, title: "Water", current: 5, target: 8, label: "glasses", priority: 1, isSkippedToday: false),
            NeuralLoopWidgetHabit(id: 3, title: "Read", current: 1, target: 1, label: "chapter", priority: 2, isSkippedToday: false)
        ]
    )
}

// MARK: - Widget Entry View

struct NeuralLoopCalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: NeuralLoopCalendarEntry

    private var tasksURL: URL {
        URL(string: "neural-loop://tasks")!
    }

    private var habitsURL: URL {
        URL(string: "neural-loop://habits")!
    }

    var body: some View {
        ZStack {
            background

            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemLarge:
                largeLayout
            default:
                smallLayout
            }
        }
        .widgetURL(tasksURL)
        .containerBackground(for: .widget) {
            background
        }
    }

    private var activeTasks: [NeuralLoopWidgetTask] {
        Array(entry.snapshot.tasks.prefix(family == .systemLarge ? 5 : 2))
    }

    private var displayedHabits: [NeuralLoopWidgetHabit] {
        Array(entry.snapshot.habits.prefix(family == .systemLarge ? 5 : 2))
    }

    private var taskCountText: String {
        "\(entry.snapshot.tasks.count) task\(entry.snapshot.tasks.count == 1 ? "" : "s")"
    }

    private var habitCountText: String {
        let remaining = entry.snapshot.habits.filter { !$0.isComplete && !$0.isSkippedToday }.count
        return "\(remaining) habit\(remaining == 1 ? "" : "s")"
    }

    private var background: some View {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color(red: 0.03, green: 0.04, blue: 0.06),
                Color(red: 0.07, green: 0.09, blue: 0.13),
                Color(red: 0.08, green: 0.12, blue: 0.11)
            ] : [
                Color(red: 0.98, green: 0.98, blue: 0.95),
                Color(red: 0.92, green: 0.97, blue: 0.96),
                Color(red: 0.96, green: 0.94, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactHeader

            HStack(spacing: 8) {
                MetricPill(title: "", value: "\(entry.snapshot.tasks.count)", tint: .cyan, systemImage: "checklist")
                MetricPill(title: "", value: "\(entry.snapshot.habits.filter { !$0.isComplete && !$0.isSkippedToday }.count)", tint: .green,
                           systemImage: "repeat.circle")
            }

            VStack(alignment: .leading, spacing: 6) {
                if let task = activeTasks.first {
                    Link(destination: tasksURL) {
                        TaskLine(task: task, isCompact: true)
                    }
                }

                if let habit = displayedHabits.first {
                    Link(destination: habitsURL) {
                        HabitLine(habit: habit, isCompact: true)
                    }
                }

                if activeTasks.isEmpty && displayedHabits.isEmpty {
                    EmptyWidgetMessage(text: "Nothing due today")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            HStack(alignment: .top, spacing: 12) {
                Link(destination: tasksURL) {
                    WidgetSection(
                        title: "To Do",
                        subtitle: taskCountText,
                        tint: .cyan,
                        systemImage: "checklist"
                    ) {
                        if activeTasks.isEmpty {
                            EmptyWidgetMessage(text: "No tasks due")
                        } else {
                            ForEach(Array(activeTasks.enumerated()), id: \.offset) { _, task in
                                TaskLine(task: task, isCompact: false)
                            }
                        }
                    }
                }

                Link(destination: habitsURL) {
                    WidgetSection(
                        title: "Habits",
                        subtitle: habitCountText,
                        tint: .green,
                        systemImage: "repeat.circle"
                    ) {
                        if displayedHabits.isEmpty {
                            EmptyWidgetMessage(text: "Habits clear")
                        } else {
                            ForEach(Array(displayedHabits.enumerated()), id: \.offset) { _, habit in
                                HabitLine(habit: habit, isCompact: false)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top, spacing: 14) {
                Link(destination: tasksURL) {
                    WidgetSection(
                        title: "To Do",
                        subtitle: taskCountText,
                        tint: .cyan,
                        systemImage: "checklist"
                    ) {
                        if activeTasks.isEmpty {
                            EmptyWidgetMessage(text: "No tasks due today")
                        } else {
                            ForEach(Array(activeTasks.enumerated()), id: \.offset) { _, task in
                                TaskLine(task: task, isCompact: false)
                            }
                        }
                    }
                }

                Link(destination: habitsURL) {
                    WidgetSection(
                        title: "Habits",
                        subtitle: habitCountText,
                        tint: .green,
                        systemImage: "repeat.circle"
                    ) {
                        if displayedHabits.isEmpty {
                            EmptyWidgetMessage(text: "Habits clear")
                        } else {
                            ForEach(Array(displayedHabits.enumerated()), id: \.offset) { _, habit in
                                HabitLine(habit: habit, isCompact: false)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            FooterStatus(updatedAt: entry.snapshot.updatedAt)
        }
        .padding(16)
    }

    private var compactHeader: some View {
        HStack(spacing: 8) {
            DateBadge(date: entry.date, compact: true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(entry.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            DateBadge(date: entry.date, compact: true)

            VStack(alignment: .leading, spacing: 2) {
                
                    Text("Today")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(entry.date.formatted(.dateTime.weekday(.wide)))")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
            }
            HStack(spacing: 8) {
                MetricPill(title: "To do", value: "\(entry.snapshot.tasks.count)", tint: .cyan, systemImage: "checklist")
                MetricPill(title: "Habits", value: "\(entry.snapshot.habits.filter { !$0.isComplete && !$0.isSkippedToday }.count)", tint: .green,
                           systemImage: "repeat.circle")
            }

        }
    }
}

// MARK: - Subviews

private struct DateBadge: View {
    let date: Date
    let compact: Bool

    var body: some View {
        VStack(spacing: -1) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(size: compact ? 6 : 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            Text(date.formatted(.dateTime.day()))
                .font(.system(size: compact ? 16 : 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.86, green: 0.18, blue: 0.20))
        )
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let tint: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            
            Image(systemName: systemImage)
                .resizable() // Allow the icon to scale
                .scaledToFit() // Maintain aspect ratio
                .foregroundStyle(tint) // This is the "fill" for images
                .frame(width: 12, height: 12)
            

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary).opacity(0.8)
                .monospacedDigit()

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary).opacity(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WidgetSection<Content: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        tint: Color,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint).opacity(0.8)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

//                    Text(subtitle)
//                        .font(.system(size: 10, weight: .medium, design: .rounded))
//                        .foregroundStyle(.secondary)
//                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .buttonStyle(.plain)
    }
}

private struct TaskLine: View {
    let task: NeuralLoopWidgetTask
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Circle()
                .strokeBorder(priorityColor, lineWidth: 1.6)
                .frame(width: isCompact ? 10 : 12, height: isCompact ? 10 : 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !isCompact {
                    Text(dueText)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case 3:
            return .red
        case 2:
            return .orange
        case 1:
            return .cyan
        default:
            return .secondary
        }
    }

    private var dueText: String {
        guard let startDate = task.startDate else { return "Inbox" }

        if Calendar.current.isDateInToday(startDate) {
            return startDate.formatted(date: .omitted, time: .shortened)
        }

        return "Overdue"
    }
}

private struct HabitLine: View {
    let habit: NeuralLoopWidgetHabit
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            ProgressRing(progress: habit.ratio, isComplete: habit.isComplete)
                .frame(width: isCompact ? 13 : 16, height: isCompact ? 13 : 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(habit.title)
                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !isCompact {
                    Text(progressText)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var progressText: String {
        let label = habit.label.map { " \($0)" } ?? ""
        return "\(habit.current)/\(habit.target)\(label)"
    }
}

private struct ProgressRing: View {
    let progress: Double
    let isComplete: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.22), lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(isComplete ? Color.green : Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct EmptyWidgetMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FooterStatus: View {
    let updatedAt: Date

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .bold))

            Text("Updated \(updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Widget Configuration

struct NeuralLoopCalendarWidget: Widget {
    let kind: String = NeuralLoopWidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NeuralLoopCalendarProvider()) { entry in
            NeuralLoopCalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Loop Today")
        .description("See today's tasks and habit progress, then jump into Neural Loop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview("Loop Today Small", as: .systemSmall) {
    NeuralLoopCalendarWidget()
} timeline: {
    NeuralLoopCalendarEntry(date: .now, snapshot: NeuralLoopCalendarProvider.previewSnapshot)
}

#Preview("Loop Today Medium", as: .systemMedium) {
    NeuralLoopCalendarWidget()
} timeline: {
    NeuralLoopCalendarEntry(date: .now, snapshot: NeuralLoopCalendarProvider.previewSnapshot)
}

#Preview("Loop Today Large", as: .systemLarge) {
    NeuralLoopCalendarWidget()
} timeline: {
    NeuralLoopCalendarEntry(date: .now, snapshot: NeuralLoopCalendarProvider.previewSnapshot)
}
