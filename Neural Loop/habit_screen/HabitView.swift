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

struct HabitView: View {

//    @StateObject private var vm = HabitViewModel()
    
    @State private var addProgressToHabit: Habits? = nil
    @State private var showAddHabit: Bool = false
    @State private var selectedHabit: Habits? = nil
    
    @EnvironmentObject var model: UnifiedDataModel
    

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(model.habits , id: \.id) { habit in
                        if let id = habit.id,
                           let progress = model.habitProgressMap[id]{
                            HabitCardView(
                                habit: habit,
                                progress: progress,
                                onIncrement: {
                                    Task {
                                        await model.incrementHabit(habit, value:1)
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
                                        await model.deleteHabit(habit)
                                        
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
            
            .sheet(isPresented: $showAddHabit) {
                AddEditHabitView(habit: nil){new_habit in
                    Task {
                        await model.saveNewHabit(new_habit)
                        
                    }
                    
                }
            }
            .sheet(item: $selectedHabit) { habit in
                AddEditHabitView(habit: habit) { updatedHabit in
                    Task {
                        await model.updateHabit(updatedHabit)
                        
                    }
                }
            }
            .sheet(item: $addProgressToHabit) { habit in
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
