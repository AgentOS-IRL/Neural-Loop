//
//  CalendarDayView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 15/01/2026.
//

import SwiftUI
import Combine

let hourHeight: CGFloat = 120   // 1 hour = 60 points
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
                    .font(.caption2)
                    .opacity(0.8)
            }
        }
        .padding(8)
        .frame(height: taskHeight)
        .background(priorityColor)
        .cornerRadius(8)
    }

    private var taskHeight: CGFloat {
        let duration = task.duration ?? 3600
        return CGFloat(duration / 3600) * hourHeight
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

struct TaskOverlayView: View {
    let date: Date
    let tasks: [Tasks]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(tasksForDay) { task in
                TaskBlockView(task: task)
                    .offset(y: yOffset(for: task))
            }
        }
        .padding(.leading, 60)
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

        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight
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
        }.toolbar {
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
        }
        .background(Color.black)
        .onAppear {
            Task {
                let dbmanager = DBManager.newInstance()
                tasks = try await dbmanager.fetchAllTasksByDate(date: date)
            }
        }
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
