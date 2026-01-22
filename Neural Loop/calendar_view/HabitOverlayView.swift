import SwiftUI

struct HabitOverlayView: View {
    let date: Date
    /// Dictionary of habit name -> array of completion dates (with time)
    let habits: [String: [Date]]

    private let leftGutter: CGFloat = 60
    private let columnSpacing: CGFloat = 6
    /// Duration used to consider two habits as overlapping (columns)
    private let overlapWindow: TimeInterval = 15 * 60

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(0, geo.size.width - leftGutter - 8)
            let laidOut = layoutHabits(habitEvents)

            ZStack(alignment: .topLeading) {
                ForEach(laidOut, id: \.id) { item in
                    let colWidth = columnWidth(totalWidth: availableWidth, columns: item.columnCount)

                    HabitBlockView(title: item.event.title)
                        .frame(width: colWidth, alignment: .leading)
                        .offset(
                            x: leftGutter + (CGFloat(item.column) * (colWidth + columnSpacing)),
                            y: yOffset(for: item.event.time)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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

    // MARK: - Layout (overlaps -> columns)

    private struct LayoutItem: Identifiable {
        let id = UUID()
        let event: HabitEvent
        let column: Int
        let columnCount: Int
        let start: Date
        let end: Date
    }

    private struct Interval {
        let event: HabitEvent
        let start: Date
        let end: Date
    }

    private func layoutHabits(_ events: [HabitEvent]) -> [LayoutItem] {
        let intervals: [Interval] = events
            .map { Interval(event: $0, start: $0.time, end: $0.time.addingTimeInterval(overlapWindow)) }
            .sorted { $0.start < $1.start }

        struct Active {
            let end: Date
            let col: Int
            let interval: Interval
        }

        var result: [LayoutItem] = []
        var active: [Active] = []
        var cluster: [(interval: Interval, col: Int)] = []
        var clusterMaxCols: Int = 0

        func finalizeCluster() {
            guard !cluster.isEmpty else { return }
            for (interval, col) in cluster {
                result.append(
                    LayoutItem(
                        event: interval.event,
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
            // Remove finished before this starts
            active.removeAll { $0.end <= interval.start }
            if active.isEmpty { finalizeCluster() }

            // Smallest available column
            let usedCols = Set(active.map { $0.col })
            var col = 0
            while usedCols.contains(col) { col += 1 }

            active.append(Active(end: interval.end, col: col, interval: interval))
            cluster.append((interval: interval, col: col))
            clusterMaxCols = max(clusterMaxCols, active.count)
        }

        finalizeCluster()

        return result.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.column < $1.column
        }
    }

    private func columnWidth(totalWidth: CGFloat, columns: Int) -> CGFloat {
        guard columns > 0 else { return totalWidth }
        let totalSpacing = CGFloat(max(0, columns - 1)) * columnSpacing
        return max(0, (totalWidth - totalSpacing) / CGFloat(columns))
    }
}
