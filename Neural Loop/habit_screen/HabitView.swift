//
//  HabitView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//
import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class HabitViewModel: ObservableObject {
    // Source of truth
    @Published var habits: [Habits] = [] {
        didSet {
            Task {
                await rebuildProgressMap()
            }
        }
    }
    @Published private(set) var progressMap: [Int64: HabitProgress] = [:]
    @Published var error: String?
    
    
    func loadHabits() async {
        print("Fetching Habits")
        do {
            let manager = DBManager.newInstance()
            let fetched = try await manager.fetchAllHabits()
            habits = fetched

            
        } catch {
            self.error = error.localizedDescription
        }
    }
    private func rebuildProgressMap() async {
        do {
            var map: [Int64: HabitProgress] = [:]
            for habit in habits {
                guard let id = habit.id else { continue }
                let progress = try await computeProgress(for: habit)
                map[id] = progress
            }
            progressMap = map
        } catch {
            self.error = error.localizedDescription
        }
        
    }

    func incrementHabit(_ habit: Habits) async {
        guard let id = habit.id else { return }
        do {
            let manager = DBManager.newInstance()
            _ = try await manager.addHabitEntry(
                habitId: id,
                value: 1,
                date: Date()
            )
            let index = self.habits.firstIndex(where: { $0.id == habit.id! })!
            habits[index] = habit
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveNewHabit(_ habit: Habits) async {
        do {
            let manager = DBManager.newInstance()
            let newHabit = try await manager.addHabit(habit)
            let index = self.habits.firstIndex(where: { $0.id == habit.id! })!
            habits[index] = newHabit
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateHabit(_ habit: Habits) async {
        do {
            let manager = DBManager.newInstance()
            try await manager.updateHabit(habit)
            let index = self.habits.firstIndex(where: { $0.id == habit.id! })!
            habits[index] = habit
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteHabit(_ habit: Habits) async {
        guard let id = habit.id else { return }
        do {
            let manager = DBManager.newInstance()
            try await manager.deleteHabit(id: id)
            let index = self.habits.firstIndex(where: { $0.id == habit.id! })!
            habits.remove(at: index)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func computeProgress(
        for habit: Habits,
        reference: Date = .now
    ) async throws -> HabitProgress {

        let manager = DBManager.newInstance()
        let window = HabitWindow.window(for: habit, reference: reference)

        let entries = try await manager.fetchHabitEntries(
            forTask: habit.id!,
            from: window.start,
            to: window.end
        )

        let total = entries.reduce(0) { $0 + $1.value }

        return HabitProgress(
            current: total,
            target: Int(habit.target),
            targetLabel: habit.label ?? "Times",
            windowLabel: window.label
        )
    }
}

struct HabitView: View {

    @StateObject private var vm = HabitViewModel()
    
    @State private var addProgressToHabit: Habits? = nil
    @State private var showAddHabit: Bool = false
    @State private var selectedHabit: Habits? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(vm.habits, id: \.id) { habit in
                        if let id = habit.id,
                           let progress = vm.progressMap[id] {
                            HabitCardView(
                                habit: habit,
                                progress: progress,
                                onIncrement: {
                                    Task {
                                        await vm.incrementHabit(habit)
                                    }
                                }
                            )
                            .onTapGesture {
                                addProgressToHabit = habit
                            }
                            .contextMenu {
                                Button {
                                    selectedHabit = habit
                                } label: {
                                    Label("Edit Habit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await vm.deleteHabit(habit)
                                        
                                    }
                                } label: {
                                    Label("Delete Habit", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                }
                .padding()
            }.refreshable {
                await vm.loadHabits()
            }
//            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Habits")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)  // don’t compress horizontally
                        .layoutPriority(1)                             // fight for space
                        .padding(.horizontal, 12)
                    
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                             showAddHabit = true
                        }
                }
            }
            .onAppear {
                Task { await vm.loadHabits() }
            }
            .sheet(isPresented: $showAddHabit) {
                AddEditHabitView(habit: nil){new_habit in
                    Task {
                        await vm.saveNewHabit(new_habit)
                        
                    }
                    
                }
            }
            .sheet(item: $selectedHabit) { habit in
                AddEditHabitView(habit: habit) { updatedHabit in
                    Task {
                        await vm.updateHabit(updatedHabit)
                        
                    }
                }
            }
            .sheet(item: $addProgressToHabit, onDismiss: {
                Task { await vm.loadHabits() }
            }) { habit in
                AddProgressView(habit: habit) {}
            }
        }
    }
}



// MARK: - UI

struct HabitCardView: View {
    let habit: Habits
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
                Text("\(progress.current) / \(progress.target) \(progress.targetLabel)")
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
