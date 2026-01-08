//
//  HabitView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//

import SwiftUI
import SwiftData

struct HabitView: View {

    @State private var habits: [Tasks] = []
    @State private var progressMap: [Int64: HabitProgress] = [:]
    @State private var error: String?

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(habits, id: \.id) { habit in
                        if let id = habit.id,
                           let progress = progressMap[id] {
                            HabitCardView(
                                habit: habit,
                                progress: progress,
                                onIncrement: {
                                    Task {
                                        await incrementHabit(habit)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Habits")
            .onAppear {
                Task {
                    await loadHabits()
                }
            }
        }
    }

    // MARK: - Data loading (read-only)

    @MainActor
    private func loadHabits() async {
        do {
            let manager = DBManager.newInstance()
            let fetched = try await manager.fetchAllTasks(get_habits: true)
            habits = fetched

            var map: [Int64: HabitProgress] = [:]
            for habit in fetched {
                guard let id = habit.id else { continue }
                let progress = try await computeProgress(for: habit, manager: manager)
                map[id] = progress
            }
            progressMap = map
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func computeProgress(for habit: Tasks, manager: DBManager) async throws -> HabitProgress {
        let now = Date()
        let window = HabitWindow.window(for: habit, reference: now)

        let entries = try await manager.fetchHabitEntries(
            forTask: habit.id!,
            from: window.start,
            to: window.end
        )

        let total = entries.reduce(0) { $0 + $1.value }
        let target = Int(habit.target ?? 0)

        return HabitProgress(
            current: total,
            target: target,
            windowLabel: window.label
        )
    }

    private func incrementHabit(_ habit: Tasks) async {
        guard let id = habit.id else { return }
        do {
            let manager = DBManager.newInstance()
            _ = try await manager.addHabitEntry(taskId: id, value: 1, date: Date())
            await loadHabits() // refresh UI after update
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Supporting Models

struct HabitProgress {
    let current: Int
    let target: Int
    let windowLabel: String

    var ratio: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
}

struct HabitWindow {
    let start: Date
    let end: Date
    let label: String

    static func window(for habit: Tasks, reference: Date) -> HabitWindow {
        guard
            let ruleString = habit.recursion_rule,
            let rule = try? parse_rrule(rruleString: ruleString)
        else {
            return day(reference)
        }

        switch rule.frequency {
        case .daily:
            return day(reference)
        case .weekly:
            return week(reference)
        case .monthly:
            return month(reference)
        default:
            return day(reference)
        }
    }

    private static func day(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        return HabitWindow(
            start: cal.startOfDay(for: date),
            end: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!,
            label: "Today"
        )
    }

    private static func week(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return HabitWindow(start: start, end: end, label: "This Week")
    }

    private static func month(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        return HabitWindow(start: start, end: end, label: "This Month")
    }
}

// MARK: - UI

struct HabitCardView: View {
    let habit: Tasks
    let progress: HabitProgress
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(habit.title)
                    .font(.headline)

                Spacer()

                Text(progress.windowLabel.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(progress.current), total: Double(progress.target))
                .progressViewStyle(.linear)

            HStack {
                Text("\(progress.current) / \(progress.target)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onIncrement) {
                    Text("+1")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                statusLabel
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var statusLabel: some View {
        let ratio = progress.ratio

        let text: String
        let color: Color

        switch ratio {
        case 1.0:
            text = "Completed"
            color = .green
        case 0.7...:
            text = "On Track"
            color = .yellow
        default:
            text = "Behind"
            color = .orange
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
    }
}
