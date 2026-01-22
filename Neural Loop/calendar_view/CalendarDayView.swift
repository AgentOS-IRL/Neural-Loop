//
//  CalendarDayView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 15/01/2026.
//

import SwiftUI
import Combine
import EventKit

struct SimpleEvent {
    let title: String
    let start: Date
    let end: Date
}

func fetchTodaysGenesysEvents(
    ignorePrefix: String = "sanjeev halyal",
    completion: @escaping ([SimpleEvent]) -> Void
) {
    let eventStore = EKEventStore()

    eventStore.requestAccess(to: .event) { granted, _ in
        guard granted else {
            completion([])
            return
        }

        let calendar = Calendar.current
        let now = Date()

        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            completion([])
            return
        }

        // 🔎 Find Genesys Exchange source (NO closures)
        var genesysSource: EKSource?
        for source in eventStore.sources {
            if source.sourceType == .exchange && source.title == "Genesys" {
                genesysSource = source
                break
            }
        }

        guard let source = genesysSource else {
            completion([])
            return
        }

        let calendars = Array(source.calendars(for: .event))
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: calendars
        )

        let events = eventStore.events(matching: predicate)

        // 🎯 Find priority event
        var priorityEvent: EKEvent?
        for event in events {
            if event.title.lowercased().hasPrefix(ignorePrefix) {
                priorityEvent = event
                break
            }
        }

        // 🧹 Filter overlaps
        var filtered: [EKEvent] = []

        if let priority = priorityEvent {
            for event in events {
                if event === priority ||
                    event.endDate <= priority.startDate ||
                    event.startDate >= priority.endDate {
                    filtered.append(event)
                }
            }
        } else {
            filtered = events
        }

        // 📦 Map result
        let result = filtered
            .sorted { $0.startDate < $1.startDate }
            .map {
                SimpleEvent(
                    title: $0.title,
                    start: $0.startDate,
                    end: $0.endDate
                )
            }

        completion(result)
    }
}

let hourHeight: CGFloat = 120   // 1 hour = 120 points
let hoursInDay = 24

struct TaskBlockView: View {
    let task: Tasks

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.caption)
                .bold()

            if let description = task.description {
                Text(description)
                    .font(.caption)
                    .opacity(0.8)
            }
        }
        .padding(8)
        .frame(height: taskHeight)
        .background(
            task.is_completed == true
            ? priorityColor.opacity(0.3)
            : priorityColor
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    task.is_completed == true
                    ? priorityColor.opacity(0.8)
                    : Color.clear,
                    style: StrokeStyle(lineWidth: 1.5, dash: task.is_completed == true ? [6] : [])
                )
        )
        .cornerRadius(8)
        .opacity(task.is_completed == true ? 0.6 : 1.0)
    }

    private var taskHeight: CGFloat {
        let duration = task.duration ?? 3600
        return CGFloat(duration) / 3600 * hourHeight
    }

    private var priorityColor: Color {
        switch task.priority {
        case 3: return Color.red.opacity(0.9)
        case 2: return Color.orange.opacity(0.9)
        case 1: return Color.blue.opacity(0.9)
        default: return Color.gray.opacity(0.7)
        }
    }
}

struct HabitBlockView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.85))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct HabitOverlayView: View {
    let date: Date
    /// Dictionary of habit name -> array of completion dates (with time)
    let habits: [String: [Date]]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(habitEvents, id: \.id) { event in
                HabitBlockView(title: event.title)
                    .offset(y: yOffset(for: event.time))
            }
        }
        .padding(.leading, 60)
    }

    // Flatten dictionary into a list of occurrences for the currently selected day
    private var habitEvents: [HabitEvent] {
        var events: [HabitEvent] = []

        for (habitName, dates) in habits {
            for d in dates where Calendar.current.isDate(d, inSameDayAs: date) {
                events.append(HabitEvent(title: habitName, time: d))
            }
        }

        // Sort by time so they render in order
        events.sort { $0.time < $1.time }
        return events
    }

    private func yOffset(for time: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight
    }

    private struct HabitEvent: Identifiable {
        let id = UUID()
        let title: String
        let time: Date
    }
}

/// Overlapping tasks are laid out side-by-side (calendar-style)
struct TaskOverlayView: View {
    let date: Date
    let tasks: [Tasks]

    private let leftGutter: CGFloat = 60
    private let columnSpacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(0, geo.size.width - leftGutter - 8)
            let laidOut = layoutTasks(tasksForDay)

            ZStack(alignment: .topLeading) {
                ForEach(laidOut) { item in
                    let colWidth = columnWidth(totalWidth: availableWidth, columns: item.columnCount)

                    TaskBlockView(task: item.task)
                        .frame(width: colWidth)
                        .offset(
                            x: leftGutter + (CGFloat(item.column) * (colWidth + columnSpacing)),
                            y: yOffset(for: item.task)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var tasksForDay: [Tasks] {
        tasks.filter {
            guard let start = $0.start_date else { return false }
            return Calendar.current.isDate(start, inSameDayAs: date)
        }
    }

    private func yOffset(for task: Tasks) -> CGFloat {
        guard let start = task.start_date else { return 0 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: start)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight
    }

    private func taskEndDate(_ task: Tasks) -> Date {
        let start = task.start_date ?? date
        let duration = TimeInterval(task.duration ?? 3600)
        return start.addingTimeInterval(duration)
    }

    private func columnWidth(totalWidth: CGFloat, columns: Int) -> CGFloat {
        guard columns > 0 else { return totalWidth }
        let totalSpacing = CGFloat(max(0, columns - 1)) * columnSpacing
        return max(0, (totalWidth - totalSpacing) / CGFloat(columns))
    }

    // MARK: - Layout (overlaps -> columns)

    private struct LayoutItem: Identifiable {
        let id = UUID()
        let task: Tasks
        let column: Int
        let columnCount: Int
        let start: Date
        let end: Date
    }

    private struct Interval {
        let task: Tasks
        let start: Date
        let end: Date
    }

    /// Assign tasks into columns so overlaps are side-by-side.
    /// Uses a greedy interval coloring strategy per overlap-cluster.
    private func layoutTasks(_ tasks: [Tasks]) -> [LayoutItem] {
        let intervals: [Interval] = tasks.compactMap { t in
            guard let start = t.start_date else { return nil }
            let end = taskEndDate(t)
            return Interval(task: t, start: start, end: end)
        }
        .sorted { $0.start < $1.start }

        // Active set holds (end, col, interval)
        struct Active {
            let end: Date
            let col: Int
            let interval: Interval
        }

        var result: [LayoutItem] = []
        var active: [Active] = []

        // Current cluster (continuous overlaps)
        var cluster: [(interval: Interval, col: Int)] = []
        var clusterMaxCols: Int = 0

        func finalizeCluster() {
            guard !cluster.isEmpty else { return }
            for (interval, col) in cluster {
                result.append(
                    LayoutItem(
                        task: interval.task,
                        column: col,
                        columnCount: max(1, clusterMaxCols),
                        start: interval.start,
                        end: interval.end
                    )
                )
            }
            cluster.removeAll()
            clusterMaxCols = 0
        }

        for interval in intervals {
            // Remove tasks that ended before this starts
            active.removeAll { $0.end <= interval.start }

            // If nothing is active, we finished a cluster
            if active.isEmpty {
                finalizeCluster()
            }

            // Find smallest available column index
            let usedCols = Set(active.map { $0.col })
            var col = 0
            while usedCols.contains(col) { col += 1 }

            active.append(Active(end: interval.end, col: col, interval: interval))
            cluster.append((interval: interval, col: col))

            // Track max parallel overlaps within this cluster
            clusterMaxCols = max(clusterMaxCols, active.count)
        }

        finalizeCluster()

        // Preserve visual order by start time, then column
        return result.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.column < $1.column
        }
    }
}

struct TimeGridView: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<hoursInDay, id: \.self) { hour in
                HStack(alignment: .top) {
                    Text(timeLabel(for: hour))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 50, alignment: .trailing)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 0.5)
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
    }

    private func timeLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

struct CurrentTimeIndicatorView: View {
    let date: Date
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if Calendar.current.isDateInToday(date) {
            HStack(spacing: 0) {

                // Time capsule
                Text(timeString(from: now))
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())

                // Continuous red line
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1)
            }
            .offset(y: yOffset)
            .padding(.leading, 8)
            .onReceive(timer) { now = $0 }
        }
    }

    private var yOffset: CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight + hourHeight/2
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct DateBarView: View {
    let today = Date()
    let day = Calendar.current.component(.day, from: Date())

    @State private var selectedDate: Date
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current

    init(selectedDate: Date, onSelect: @escaping (Date) -> Void) {
        _selectedDate = State(initialValue: selectedDate)
        self.onSelect = onSelect
    }

    private var dates: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: selectedDate)
        else { return [] }

        return calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0)
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        let day = date.startOfDay
                        dateCell(day)
                            .id(day)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(selectedDate.startOfDay, anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                withAnimation(.easeInOut) {
                    proxy.scrollTo(newValue.startOfDay, anchor: .center)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)  // don’t compress horizontally
                    .layoutPriority(1)                             // fight for space
                    .padding(.horizontal, 12)
            }

            // Trailing actions: calendar + plus
            ToolbarItem(placement: .automatic) {
                Button {
                    selectedDate = today
                    onSelect(today)
                } label: {
                    Image(systemName: "\(Calendar.current.component(.day, from: today)).calendar")
                        .font(.system(size: 21, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // add task action
                    } label: {
                        Label("Add Task", systemImage: "checkmark.circle")
                    }

                    Button {
                        // add habit action
                    } label: {
                        Label("Add Habit", systemImage: "repeat")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func todayButton() -> some View {
        let today = Date()
        let day = Calendar.current.component(.day, from: today)

        return ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)

            Image(systemName: "\(day).calendar")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 50, height: 50)
        .onTapGesture {
            selectedDate = today
            onSelect(today)
        }
    }

    func dateCell(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.short)))
                .font(.caption)
                .foregroundColor(.gray)

            Text(date.formatted(.dateTime.day()))
                .font(.headline)
        }
        .frame(width: 44, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                    ? Color.blue
                    : isToday
                    ? Color.blue.opacity(0.3)
                    : Color.clear
                )
        )
        .foregroundColor(isSelected ? .white : .primary)
        .onTapGesture {
            selectedDate = date
            onSelect(date)
        }
    }
}

private extension Calendar {
    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)

        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            guard let date else { return }
            if date < interval.end {
                dates.append(date)
            } else {
                stop = true
            }
        }
        return dates
    }
}

struct CalendarDayView: View {
    @State private var date: Date = .now
    @State private var tasks: [Tasks] = []
    @State private var habits: [String: [Date]] = [:]
    @State private var workEvents: [SimpleEvent] = []

    @EnvironmentObject var model: UnifiedDataModel

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in

                DateBarView(selectedDate: date) { newDate in
                    date = newDate
                }

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        TimeGridView()
                        TaskOverlayView(date: date, tasks: tasks)
                        HabitOverlayView(date: date, habits: habits)
                        CurrentTimeIndicatorView(date: date)
                    }
                    .frame(height: CGFloat(hoursInDay) * hourHeight)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        let hour = Calendar.current.component(.hour, from: Date())
                        proxy.scrollTo(hour, anchor: .top)
                    }
                }

            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: SAFE_AREA_INSET)
            }
        }
        .background(Color.black)
        .onAppear {
            Task {
                tasks = await model.getTasks(date: date)
                habits = WaterAutoScheduling.shared.get_calendar_data()
                fetchTodaysGenesysEvents() { events in
                    workEvents = events
                }
            }
        }
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func ISO8601FormatIfAvailable() -> String? {
        // Always format to full ISO-8601 string
        ISO8601DateFormatter().string(from: self)
    }
}
