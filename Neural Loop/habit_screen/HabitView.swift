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
    let embeddedInTaskHub: Bool

    init(embeddedInTaskHub: Bool = false) {
        self.embeddedInTaskHub = embeddedInTaskHub
    }

//    @StateObject private var vm = HabitViewModel()
    
    @State private var addProgressToHabit: Habits? = nil
    @State private var showAddHabit: Bool = false
    @State private var selectedHabit: Habits? = nil
    
    @EnvironmentObject var model: UnifiedDataModel

    private var bottomInsetHeight: CGFloat {
        embeddedInTaskHub ? SAFE_AREA_INSET + 104 : SAFE_AREA_INSET
    }

    @ViewBuilder
    private var habitRootContent: some View {
        ZStack {
            FleetingNotesTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if embeddedInTaskHub {
                        habitEmbeddedHeader
                    }

                    ForEach(model.habits, id: \.id) { habit in
                        if let id = habit.id,
                           let progress = model.currentHabitProgressMap[id] {
                            HabitCardView(
                                habit: habit,
                                progress: progress,
                                onIncrement: {
                                    Task {
                                        await model.incrementHabit(habit, value: 1)
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
                Color.clear.frame(height: bottomInsetHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var habitEmbeddedHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Habits")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(FleetingNotesTheme.textPrimary)
                Text("Track recurring actions and streaks.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(FleetingNotesTheme.textSecondary)
            }

            Spacer()

            Button {
                showAddHabit = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FleetingNotesTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(FleetingNotesTheme.sectionGradient)
                    )
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    do {
                        try await model.manager.reloadHabitEntries(refresh: true)
                    } catch {
                        print("Error Refreshing the Habit Entries")
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FleetingNotesTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(FleetingNotesTheme.sectionGradient)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(FleetingNotesTheme.heroGradient)
        .overlay {
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
        }
        .cornerRadius(FleetingNotesTheme.Metrics.cardCornerRadius)
    }

    var body: some View {
        Group {
            if embeddedInTaskHub {
                habitRootContent
            } else {
                NavigationView {
                    habitRootContent
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Text("Habits")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(FleetingNotesTheme.textPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)
                                    .padding(.horizontal, 12)
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(FleetingNotesTheme.textSecondary)
                                    .onTapGesture {
                                        showAddHabit = true
                                    }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Image(systemName: "arrow.clockwise.square")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(FleetingNotesTheme.textSecondary)
                                    .onTapGesture {
                                        Task {
                                            do {
                                                try await model.manager.reloadHabitEntries(refresh: true)
                                            } catch {
                                                print("Error Refreshing the Habit Entries")
                                            }
                                        }
                                    }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showAddHabit) {
            AddEditHabitView(habit: nil) { new_habit in
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(habit.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(FleetingNotesTheme.textPrimary)
                
                statusLabel
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(progress.current) / \(progress.target) \(progress.targetLabel)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(FleetingNotesTheme.textSecondary)
                    
                    Text(progress.window.label.uppercased())
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(FleetingNotesTheme.accentGradient)
                        .opacity(0.8)
                }
            }

            ProgressView(value: Double(progress.current), total: Double(progress.target))
                .progressViewStyle(.linear)
                .tint(FleetingNotesTheme.glowColor)

            HStack {
                if model.progressChartData[habit.id!] ?? nil != nil {
                    ProgressChartView(habit: habit, values: model.progressChartData[habit.id!]!)
                        .padding(.vertical, 8)
                }
                
                Button(action: onIncrement) {
                    Text("+1")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            FleetingNotesTheme.accentGradient,
                            in: Capsule(style: .continuous)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .buttonStyle(.plain)

                
            }.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(FleetingNotesTheme.cardGradient)
        .overlay {
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
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
            color = FleetingNotesTheme.glowColor
        default:
            text = "Behind"
            color = FleetingNotesTheme.errorTint
        }

        return Text(text)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
