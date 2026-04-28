import SwiftUI

struct CalendarEventsOverlayView: View {
    let date: Date
    let events: [SimpleEvent]

    private let leftGutter: CGFloat = 60
    private let columnSpacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(0, geo.size.width - leftGutter - 8)
            let laidOut = layoutEvents(eventsForDay)

            ZStack(alignment: .topLeading) {
                ForEach(laidOut) { item in
                    let colWidth = columnWidth(totalWidth: availableWidth, columns: item.columnCount)

                    CalendarEventBlockView(event: item.event)
                        .frame(width: colWidth)
                        .offset(
                            x: leftGutter + (CGFloat(item.column) * (colWidth + columnSpacing)),
                            y: yOffset(for: item.event)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var eventsForDay: [SimpleEvent] {
        let calendar = Calendar.neuralLoopDisplay
        return events.filter { calendar.isDate($0.start, inSameDayAs: date) }
    }

    private func yOffset(for event: SimpleEvent) -> CGFloat {
        let comps = Calendar.neuralLoopDisplay.neuralLoopDateComponents(from: event.start)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight
    }

    private func columnWidth(totalWidth: CGFloat, columns: Int) -> CGFloat {
        guard columns > 0 else { return totalWidth }
        let totalSpacing = CGFloat(max(0, columns - 1)) * columnSpacing
        return max(0, (totalWidth - totalSpacing) / CGFloat(columns))
    }

    // MARK: - Layout for overlapping events

    private struct LayoutItem: Identifiable {
        let id = UUID()
        let event: SimpleEvent
        let column: Int
        let columnCount: Int
        let start: Date
        let end: Date
    }

    private struct Interval {
        let event: SimpleEvent
        let start: Date
        let end: Date
    }

    private func layoutEvents(_ events: [SimpleEvent]) -> [LayoutItem] {
        let intervals: [Interval] = events
            .map { Interval(event: $0, start: $0.start, end: $0.end) }
            .sorted(by: chronologicalSort)

        var result: [LayoutItem] = []
        var cluster: [Interval] = []
        var clusterEnd: Date?

        func finalizeCluster() {
            result.append(contentsOf: layoutCluster(cluster))
            cluster.removeAll()
            clusterEnd = nil
        }

        for interval in intervals {
            if let end = clusterEnd, interval.start >= end {
                finalizeCluster()
            }

            cluster.append(interval)
            clusterEnd = max(clusterEnd ?? interval.end, interval.end)
        }

        finalizeCluster()

        return result.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.column < $1.column
        }
    }

    private func layoutCluster(_ cluster: [Interval]) -> [LayoutItem] {
        guard !cluster.isEmpty else { return [] }

        let prioritizedIntervals = cluster.sorted(by: prioritySort)
        var columns: [[Interval]] = []
        var assignments: [(interval: Interval, column: Int)] = []

        for interval in prioritizedIntervals {
            var column = 0
            while column < columns.count && columns[column].contains(where: { overlaps($0, interval) }) {
                column += 1
            }

            if column == columns.count {
                columns.append([])
            }

            columns[column].append(interval)
            assignments.append((interval: interval, column: column))
        }

        return assignments.map { assignment in
            LayoutItem(
                event: assignment.interval.event,
                column: assignment.column,
                columnCount: max(1, columns.count),
                start: assignment.interval.start,
                end: assignment.interval.end
            )
        }
    }

    private func overlaps(_ lhs: Interval, _ rhs: Interval) -> Bool {
        lhs.start < rhs.end && rhs.start < lhs.end
    }

    private func chronologicalSort(_ lhs: Interval, _ rhs: Interval) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return prioritySort(lhs, rhs)
    }

    private func prioritySort(_ lhs: Interval, _ rhs: Interval) -> Bool {
        let lhsPriority = sourcePriority(for: lhs.event)
        let rhsPriority = sourcePriority(for: rhs.event)

        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.end != rhs.end { return lhs.end < rhs.end }
        return lhs.event.title.localizedCaseInsensitiveCompare(rhs.event.title) == .orderedAscending
    }

    private func sourcePriority(for event: SimpleEvent) -> Int {
        switch event.event_type {
        case .workEvent:
            return 0
        case .task:
            return 1
        case .habit:
            return 2
        }
    }
}
