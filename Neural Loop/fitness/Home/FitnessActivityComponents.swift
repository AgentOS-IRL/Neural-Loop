import SwiftUI

struct FitnessActivityPeriod {
    let startDate: Date
    let endDate: Date
    let calendar: Calendar

    static func last30Days(now: Date = Date()) -> FitnessActivityPeriod {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let endDate = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        return FitnessActivityPeriod(startDate: startDate, endDate: endDate, calendar: calendar)
    }

    var days: [Date] {
        var result: [Date] = []
        var current = startDate

        while calendar.compare(current, to: endDate, toGranularity: .day) != .orderedDescending {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return result
    }

    var monthStarts: [Date] {
        guard
            let periodStartMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)),
            let periodEndMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate))
        else {
            return []
        }

        var result: [Date] = []
        var current = periodStartMonth

        while calendar.compare(current, to: periodEndMonth, toGranularity: .month) != .orderedDescending {
            result.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        if result.count == 1,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: result[0]) {
            result.insert(previousMonth, at: 0)
        }

        return Array(result.suffix(2))
    }

    func contains(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return calendar.compare(day, to: startDate, toGranularity: .day) != .orderedAscending &&
            calendar.compare(day, to: endDate, toGranularity: .day) != .orderedDescending
    }
}

struct FitnessActivityCalendarCard: View {
    let sessions: [WorkoutSessionSummary]

    var body: some View {
        let period = FitnessActivityPeriod.last30Days()
        let countsByDay = activityCounts(in: period)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 22) {
                ForEach(period.monthStarts, id: \.self) { monthStart in
                    FitnessActivityMonthGrid(
                        monthStart: monthStart,
                        period: period,
                        activityCountsByDay: countsByDay
                    )
                }
            }

            HStack(spacing: 18) {
                legendItem(color: Color(red: 0.60, green: 0.86, blue: 0.28), title: "1 activity")
                legendItem(color: Color(red: 0.30, green: 0.74, blue: 0.50), title: "2 activities")
                legendItem(color: Color(red: 0.00, green: 0.66, blue: 0.72), title: "3+ activities")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 238, alignment: .leading)
        .background {
            AnalysisCardBackground()
        }
    }

    private func activityCounts(in period: FitnessActivityPeriod) -> [Date: Int] {
        sessions.reduce(into: [:]) { result, session in
            guard period.contains(session.date) else { return }
            let day = period.calendar.startOfDay(for: session.date)
            result[day, default: 0] += 1
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

struct FitnessActivityMonthGrid: View {
    let monthStart: Date
    let period: FitnessActivityPeriod
    let activityCountsByDay: [Date: Int]
    private static let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthStart.formatted(.dateTime.month(.abbreviated).year()))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarCells) { cell in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(for: cell))
                        .frame(height: 11)
                        .overlay {
                            if cell.isToday {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.86), lineWidth: 1.5)
                            }
                        }
                        .opacity(cell.date == nil ? 0 : 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarCells: [FitnessActivityCalendarCell] {
        let calendar = period.calendar
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let leadingBlanks = leadingBlankCount(for: monthStart, calendar: calendar)
        var cells = (0..<leadingBlanks).map { index in
            FitnessActivityCalendarCell(id: "blank-\(index)", date: nil, count: 0, isInPeriod: false, isToday: false)
        }

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dateKey = calendar.startOfDay(for: date)
            cells.append(
                FitnessActivityCalendarCell(
                    id: dateKey.timeIntervalSince1970.description,
                    date: dateKey,
                    count: activityCountsByDay[dateKey, default: 0],
                    isInPeriod: period.contains(dateKey),
                    isToday: calendar.isDateInToday(dateKey)
                )
            )
        }

        while cells.count % 7 != 0 {
            cells.append(
                FitnessActivityCalendarCell(
                    id: "trailing-\(cells.count)",
                    date: nil,
                    count: 0,
                    isInPeriod: false,
                    isToday: false
                )
            )
        }

        return cells
    }

    private func leadingBlankCount(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func color(for cell: FitnessActivityCalendarCell) -> Color {
        guard cell.date != nil else { return .clear }

        guard cell.isInPeriod else {
            return AppTheme.textSecondary.opacity(0.06)
        }

        switch cell.count {
        case 1:
            return Color(red: 0.60, green: 0.86, blue: 0.28)
        case 2:
            return Color(red: 0.30, green: 0.74, blue: 0.50)
        case 3...:
            return Color(red: 0.00, green: 0.66, blue: 0.72)
        default:
            return AppTheme.textSecondary.opacity(0.14)
        }
    }
}

struct FitnessActivityCalendarCell: Identifiable {
    let id: String
    let date: Date?
    let count: Int
    let isInPeriod: Bool
    let isToday: Bool
}

struct FitnessActivitySummaryCard: View {
    let sessions: [WorkoutSessionSummary]

    var body: some View {
        let period = FitnessActivityPeriod.last30Days()
        let series = dailyMinutes(in: period)
        let totalMinutes = series.reduce(0) { $0 + $1.minutes }

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("Activity Summary")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formatMinutes(totalMinutes))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(periodText(period))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    activityLineChart(series: series)

                    HStack {
                        Text(shortDateText(period.startDate))
                        Spacer()
                        Text(shortDateText(midpointDate(in: period)))
                        Spacer()
                        Text(shortDateText(period.endDate))
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.45))

                        Text(formatMinutes(totalMinutes))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Spacer()

                    Text("\(max(3, series.map(\.minutes).max() ?? 0))")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))

                    Spacer()

                    Text("0")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(width: 50, height: 170)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .background {
            AnalysisCardBackground()
        }
    }

    private func dailyMinutes(in period: FitnessActivityPeriod) -> [FitnessActivityDailyMinutes] {
        let minutesByDay = sessions.reduce(into: [Date: Int]()) { result, session in
            guard period.contains(session.date), let durationMinutes = session.durationMinutes else { return }
            let day = period.calendar.startOfDay(for: session.date)
            result[day, default: 0] += durationMinutes
        }

        return period.days.map { day in
            FitnessActivityDailyMinutes(date: day, minutes: minutesByDay[day, default: 0])
        }
    }

    private func activityLineChart(series: [FitnessActivityDailyMinutes]) -> some View {
        GeometryReader { proxy in
            let maxMinutes = max(3, series.map(\.minutes).max() ?? 0)
            let points = chartPoints(for: series, in: proxy.size, maxMinutes: maxMinutes)

            ZStack {
                FitnessActivityDottedTicks()
                    .stroke(
                        AppTheme.textSecondary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 14])
                    )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    Color(red: 1.0, green: 0.67, blue: 0.36),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )

                if let first = points.first {
                    Circle()
                        .fill(AppTheme.cardGradient)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(Color(red: 1.0, green: 0.67, blue: 0.36), lineWidth: 4)
                        }
                        .position(first)
                }

                if let last = points.last {
                    Circle()
                        .fill(AppTheme.cardGradient)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(Color(red: 1.0, green: 0.67, blue: 0.36), lineWidth: 5)
                        }
                        .shadow(color: Color(red: 1.0, green: 0.67, blue: 0.36).opacity(0.34), radius: 16, x: 0, y: 0)
                        .position(last)
                }
            }
        }
        .frame(height: 150)
    }

    private func chartPoints(
        for series: [FitnessActivityDailyMinutes],
        in size: CGSize,
        maxMinutes: Int
    ) -> [CGPoint] {
        guard !series.isEmpty else { return [] }

        let bottomInset: CGFloat = 18
        let topInset: CGFloat = 12
        let drawableHeight = max(size.height - topInset - bottomInset, 1)
        let denominator = max(series.count - 1, 1)

        return series.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(denominator) * size.width
            let ratio = CGFloat(value.minutes) / CGFloat(maxMinutes)
            let y = topInset + ((1 - ratio) * drawableHeight)
            return CGPoint(x: x, y: y)
        }
    }

    private func periodText(_ period: FitnessActivityPeriod) -> String {
        "\(shortDateText(period.startDate)) - \(shortDateText(period.endDate)) \(yearText(period.endDate))"
    }

    private func midpointDate(in period: FitnessActivityPeriod) -> Date {
        period.calendar.date(byAdding: .day, value: period.days.count / 2, to: period.startDate) ?? period.startDate
    }

    private func shortDateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func yearText(_ date: Date) -> String {
        date.formatted(.dateTime.year())
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }

        return "\(minutes)m"
    }
}

struct FitnessActivityDailyMinutes: Identifiable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}

struct FitnessActivityDottedTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.maxY - 18
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX, y: y))
        return path
    }
}


