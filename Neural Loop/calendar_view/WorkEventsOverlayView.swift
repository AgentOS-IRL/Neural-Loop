import SwiftUI

struct WorkEventsOverlayView: View {
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

                    WorkEventBlockView(event: item.event)
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
        events.filter { Calendar.current.isDate($0.start, inSameDayAs: date) }
    }

    private func yOffset(for event: SimpleEvent) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: event.start)
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
            active.removeAll { $0.end <= interval.start }
            if active.isEmpty { finalizeCluster() }

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
}

