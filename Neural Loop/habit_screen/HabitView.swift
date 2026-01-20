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
                           let progress = model.currentHabitProgressMap[id]{
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: SAFE_AREA_INSET)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "arrow.clockwise.square")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            Task {
                                do {
                                    try await model.manager.reloadHabitEntries(refresh: true)
                                }
                                catch {
                                    print("Error Refreshing the Habit Entries")
                                }
                            }
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

// Example input
let data: [Int: Float] = [
    -3: 0.4,
    -2: 0.0,
    -1: 0.0,
     0: 0.0,
     1: 0.0,
     2: 0.6,
     3: 0.0
]


// MARK: - Single bar

private struct Bar: View {
    let fill: CGFloat

    private var clampedFill: CGFloat {
        min(max(fill, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.gray.opacity(0.25))

                Capsule()
                    .fill(.primary)
                    .frame(height: geo.size.height * clampedFill)
                    .animation(.easeOut(duration: 0.25), value: clampedFill)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Day bar")
        .accessibilityValue("\(Int(clampedFill * 100)) percent")
    }
}

// MARK: - UI

struct HabitCardView: View {
    @EnvironmentObject var model: UnifiedDataModel
    
    
    let habit: Habits
    let progress: HabitProgress
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(habit.title)
                    .font(.headline)
                statusLabel
                Spacer()
                
                Text("\(progress.current) / \(progress.target) \(progress.targetLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(progress.window.label.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(progress.current), total: Double(progress.target))
                .progressViewStyle(.linear)

            HStack {

//                Spacer()
                if model.progressChartData[habit.id!] ?? nil != nil {
                    ProgressChartView(habit: habit, values: model.progressChartData[habit.id!]!)
                        .padding()
                }
                
                Button(action: onIncrement) {
                    Text("+1")
                        .font(.callout.weight(.semibold))   // ⬆️ bigger text
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 14)           // ⬆️ wider
                        .padding(.vertical, 8)              // ⬆️ taller
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                
            }.frame(maxWidth: .infinity, alignment: .trailing)
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
