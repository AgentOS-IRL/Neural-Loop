//
//  HabitView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//

import SwiftUI
import SwiftData

struct HabitView: View {

    @State private var habits: [Habits] = []
    @State private var progressMap: [Int64: HabitProgress] = [:]
    @State private var error: String?
    
    @State private var addProgressToHabit: Habits? = nil
    @State private var showAddHabit: Bool = false
    @State private var selectedHabit: Habits? = nil

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
                                        await deleteHabit(habit)
                                        await loadHabits()
                                    }
                                } label: {
                                    Label("Delete Habit", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                }
                .padding()
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                             showAddHabit = true
                        }
                }
            }
            .onAppear {
                Task {
                    await loadHabits()
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddEditHabitView(habit: nil){new_habit in
                    Task {
                        await saveNewHabit(new_habit: new_habit)
                        await loadHabits()
                    }
                    
                }
            }
            .sheet(item: $selectedHabit) { habit in
                AddEditHabitView(habit: habit) { updatedHabit in
                    Task {
                        await updateHabit(updatedHabit: updatedHabit)
                        await loadHabits()
                    }
                }
            }
            .sheet(item: $addProgressToHabit, onDismiss: {
                Task {
                    await loadHabits()
                }
            }) { habit in
                AddProgressView(habit: habit) {}
            }
        }
    }
    
    private func saveNewHabit(new_habit: Habits) async{
        do {
            let manager = DBManager.newInstance()
            let _ = try await manager.addHabit(new_habit)
        }
        catch {
            print("Error saving new habit", error)
        }
    }
    private func updateHabit(updatedHabit: Habits) async{
        if updatedHabit != selectedHabit
        {
            do {
                let manager = DBManager.newInstance()
                try await manager.updateHabit(updatedHabit)
            }
            catch {
                print("Error updating habit", error)
            }
        }
    }
    
    private func deleteHabit(_ habit: Habits) async {
        guard let id = habit.id else { return }
        do {
            let manager = DBManager.newInstance()
            try await manager.deleteHabit(id: id)
        } catch {
            print("Error deleting habit", error)
        }
    }

    // MARK: - Data loading (read-only)

    @MainActor
    private func loadHabits() async {
        do {
            let manager = DBManager.newInstance()
            let fetched = try await manager.fetchAllHabits()
            habits = fetched
            
            print(fetched.count)

            var map: [Int64: HabitProgress] = [:]
            for habit in fetched {
                guard let id = habit.id else { continue }
                let progress = try await computeProgress(for: habit)
                map[id] = progress
            }
            progressMap = map
        } catch {
            print(error)
            self.error = error.localizedDescription
        }
    }


    private func incrementHabit(_ habit: Habits) async {
        guard let id = habit.id else { return }
        do {
            let manager = DBManager.newInstance()
            _ = try await manager.addHabitEntry(habitId: id, value: 1, date: Date())
            await loadHabits() // refresh UI after update
        } catch {
            self.error = error.localizedDescription
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
