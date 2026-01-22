import SwiftUI

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

