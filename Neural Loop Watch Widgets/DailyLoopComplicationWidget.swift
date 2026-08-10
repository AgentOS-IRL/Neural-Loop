import AppIntents
import RelevanceKit
import SwiftUI
import WidgetKit

private enum DailyLoopWidgetStorage {
    static let suite = "group.com.sanjeevhalyal.Neural-Loop"
    static let snapshotKey = "com.neuralloop.watch.dailyLoopWidgetSnapshot.v1"

    static func load() -> DailyLoopWatchSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: suite),
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(DailyLoopWatchSnapshot.self, from: data),
            snapshot.schemaVersion == DailyLoopWatchSnapshot.currentSchemaVersion
        else {
            return nil
        }
        return snapshot
    }
}

struct DailyLoopComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyLoopWatchSnapshot?
    let isPlaceholder: Bool
}

struct DailyLoopComplicationProvider: TimelineProvider {
    private let defaultTaskDuration: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> DailyLoopComplicationEntry {
        DailyLoopComplicationEntry(date: .now, snapshot: nil, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyLoopComplicationEntry) -> Void) {
        completion(DailyLoopComplicationEntry(
            date: .now,
            snapshot: context.isPreview ? nil : DailyLoopWidgetStorage.load(),
            isPlaceholder: context.isPreview
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyLoopComplicationEntry>) -> Void) {
        let now = Date()
        let snapshot = DailyLoopWidgetStorage.load()
        let entry = DailyLoopComplicationEntry(date: now, snapshot: snapshot, isPlaceholder: false)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh(after: now, snapshot: snapshot))))
    }

    func relevance() async -> WidgetRelevance<Void> {
        guard let snapshot = DailyLoopWidgetStorage.load() else {
            return WidgetRelevance([])
        }

        var attributes = snapshot.tasks.compactMap { task -> WidgetRelevanceAttribute<Void>? in
            guard !task.isCompleted, let start = task.startDate else { return nil }
            let interval = DateInterval(
                start: start.addingTimeInterval(-30 * 60),
                end: start.addingTimeInterval(max(task.duration ?? defaultTaskDuration, 60))
            )
            return WidgetRelevanceAttribute(context: .date(interval: interval, kind: .scheduled))
        }

        if snapshot.habits.contains(where: { !$0.isComplete && !$0.isSkipped }),
           let evening = nextLocalEvening(from: .now) {
            attributes.append(
                WidgetRelevanceAttribute(context: .date(interval: evening, kind: .scheduled))
            )
        }

        return WidgetRelevance(attributes)
    }

    private func nextRefresh(after now: Date, snapshot: DailyLoopWatchSnapshot?) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        var boundaries = [
            calendar.date(byAdding: .minute, value: 30, to: now),
            calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime),
            calendar.nextDate(after: now, matching: DateComponents(hour: 18, minute: 0), matchingPolicy: .nextTime),
            calendar.nextDate(after: now, matching: DateComponents(hour: 23, minute: 59), matchingPolicy: .nextTime)
        ].compactMap { $0 }

        for task in snapshot?.tasks.filter({ !$0.isCompleted }) ?? [] {
            guard let start = task.startDate else { continue }
            boundaries.append(start.addingTimeInterval(-30 * 60))
            boundaries.append(start)
            boundaries.append(start.addingTimeInterval(max(task.duration ?? defaultTaskDuration, 60)))
        }

        return boundaries.filter { $0 > now }.min()
            ?? now.addingTimeInterval(30 * 60)
    }

    private func nextLocalEvening(from date: Date) -> DateInterval? {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: date)
        guard
            let todayStart = calendar.date(byAdding: .hour, value: 18, to: startOfDay),
            let todayEnd = calendar.date(byAdding: DateComponents(hour: 23, minute: 59, second: 59), to: startOfDay)
        else { return nil }

        if date <= todayEnd {
            return DateInterval(start: todayStart, end: todayEnd)
        }

        guard
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay),
            let start = calendar.date(byAdding: .hour, value: 18, to: tomorrow),
            let end = calendar.date(byAdding: DateComponents(hour: 23, minute: 59, second: 59), to: tomorrow)
        else { return nil }
        return DateInterval(start: start, end: end)
    }
}

private struct DailyLoopWidgetSummary {
    let nextTask: DailyLoopWatchTaskSummary?
    let remainingHabits: Int
    let progress: Double

    init(snapshot: DailyLoopWatchSnapshot?) {
        guard let snapshot else {
            nextTask = nil
            remainingHabits = 0
            progress = 0
            return
        }

        nextTask = snapshot.tasks
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                switch (lhs.startDate, rhs.startDate) {
                case let (left?, right?) where left != right: return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.priority > rhs.priority
                }
            }
            .first

        let activeHabits = snapshot.habits.filter { !$0.isSkipped }
        remainingHabits = activeHabits.filter { !$0.isComplete }.count
        let completedTasks = Double(snapshot.tasks.filter(\.isCompleted).count)
        let habitProgress = activeHabits.reduce(0.0) { $0 + $1.progress }
        let total = snapshot.tasks.count + activeHabits.count
        progress = total == 0 ? 1 : (completedTasks + habitProgress) / Double(total)
    }
}

struct DailyLoopRectangularView: View {
    let entry: DailyLoopComplicationEntry
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var summary: DailyLoopWidgetSummary { DailyLoopWidgetSummary(snapshot: entry.snapshot) }
    private var accent: Color { renderingMode == .fullColor && !isLuminanceReduced ? .cyan : .primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .widgetAccentable()
                Text("Daily Loop")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 2)
                Text("\(Int((summary.progress * 100).rounded()))%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accent)
            }

            if let task = summary.nextTask {
                Text(task.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .privacySensitive()
                HStack(spacing: 4) {
                    if let start = task.startDate {
                        Text(start, style: .time)
                            .privacySensitive()
                    } else {
                        Text("Next task")
                    }
                    Spacer(minLength: 2)
                    Text("\(summary.remainingHabits) habits")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else if entry.snapshot == nil {
                Text("Open Neural Loop to sync")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                        .widgetAccentable()
                    Text(summary.remainingHabits == 0 ? "All clear" : "Tasks complete")
                        .font(.caption2.weight(.semibold))
                    Spacer(minLength: 2)
                    Text("\(summary.remainingHabits) habits")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

struct DailyLoopCircularView: View {
    let entry: DailyLoopComplicationEntry
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var summary: DailyLoopWidgetSummary { DailyLoopWidgetSummary(snapshot: entry.snapshot) }
    private var tint: Color { renderingMode == .fullColor && !isLuminanceReduced ? .cyan : .primary }

    var body: some View {
        Gauge(value: summary.progress) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            if entry.snapshot == nil {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
            } else {
                Text("\(Int((summary.progress * 100).rounded()))")
                    .font(.caption2.monospacedDigit().weight(.bold))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tint)
        .widgetAccentable()
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .accessibilityLabel("Daily Loop progress")
        .accessibilityValue("\(Int((summary.progress * 100).rounded())) percent")
    }
}

struct DailyLoopComplicationEntryView: View {
    let entry: DailyLoopComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Button(intent: LaunchDailyLoopIntent()) {
            Group {
                if family == .accessoryCircular {
                    DailyLoopCircularView(entry: entry)
                } else {
                    DailyLoopRectangularView(entry: entry)
                }
            }
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
        .buttonStyle(.plain)
    }
}

struct DailyLoopComplicationWidget: Widget {
    let kind = "DailyLoopComplicationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyLoopComplicationProvider()) { entry in
            DailyLoopComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Loop")
        .description("Shows your next task and today's progress.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
