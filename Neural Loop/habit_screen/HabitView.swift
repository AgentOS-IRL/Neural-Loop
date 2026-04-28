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
            AppTheme.backgroundGradient
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
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Track recurring actions and streaks.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                showAddHabit = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppTheme.sectionGradient)
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
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppTheme.sectionGradient)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AppTheme.heroGradient)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .cornerRadius(AppTheme.Metrics.cardCornerRadius)
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
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)
                                    .padding(.horizontal, 12)
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .onTapGesture {
                                        showAddHabit = true
                                    }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Image(systemName: "arrow.clockwise.square")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.textSecondary)
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

    @State private var isSkippedToday = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header row: title + status + count ──────────────────────────
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(habit.title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        statusLabel
                    }
                }
                VStack{
                    
                            Text("\(progress.current) / \(progress.target) \(progress.targetLabel)  ·  \(progress.window.label.uppercased())")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .strikethrough(isSkippedToday, color: AppTheme.textSecondary)
                    // ── Progress bar ────────────────────────────────────────────────
                    ProgressView(value: Double(progress.current), total: Double(progress.target))
                        .progressViewStyle(.linear)
                        .tint(isSkippedToday ? AppTheme.textSecondary : AppTheme.glowColor)
                }
                
            }
            


            // ── Weekly chart — full width ────────────────────────────────────
            if let id = habit.id, model.progressChartData[id] != nil {
                ProgressChartView(habit: habit, values: model.progressChartData[id]!)
            }

            // ── Action row: below the chart, thumb-friendly ─────────────────
            HStack(spacing: 10) {
                // Skip — secondary, ghost style
                Button {
                    Task {
                        if isSkippedToday {
                            await model.unskipHabitToday(habit)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isSkippedToday = false }
                        } else {
                            await model.skipHabitToday(habit)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isSkippedToday = true }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isSkippedToday ? "arrow.uturn.backward" : "forward.end.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isSkippedToday ? "Unskip" : "Skip")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isSkippedToday ? AppTheme.accentColor : AppTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(isSkippedToday ? AppTheme.accentColor.opacity(0.35) : .white.opacity(0.1), lineWidth: 1)
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()

                // +1 — primary CTA, full-width pill on the right
                Button { onIncrement() } label: {
                    Label( "1", systemImage: "plus")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentGradient, in: Capsule(style: .continuous))
                        .shadow(color: AppTheme.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSkippedToday)
                .opacity(isSkippedToday ? 0.4 : 1.0)
            }
        }
        .padding(20)
        .background(AppTheme.cardGradient)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
        .onAppear {
            isSkippedToday = model.isHabitSkippedToday(habit)
        }
        .onChange(of: habit.id) { _ in
            isSkippedToday = model.isHabitSkippedToday(habit)
        }
    }

    private var statusLabel: some View {
        let ratio = progress.ratio

        let text: String
        let color: Color

        if isSkippedToday {
            text = "Skipped"
            color = AppTheme.textSecondary
        } else {
            switch ratio {
            case 1.0:
                text = "Completed"
                color = .green
            case 0.7...:
                text = "On Track"
                color = AppTheme.glowColor
            default:
                text = "Behind"
                color = AppTheme.errorTint
            }
        }

        return Text(text)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Xcode Previews

#Preview("Behind") { _HabitCardPreview(current: 1, target: 5) }
#Preview("On Track") { _HabitCardPreview(current: 4, target: 5) }
#Preview("Completed") { _HabitCardPreview(current: 5, target: 5) }
#Preview("Skipped") { _HabitCardPreview(current: 1, target: 5, skipped: true) }

private struct _HabitCardPreview: View {
    let current: Int
    let target: Int
    var skipped: Bool = false

    private let habitID: Int64 = 1

    private var habit: Habits {
        Habits(
            id: habitID,
            title: "Drink Water",
            description: "Stay hydrated",
            priority: 1,
            goal_id: nil,
            lifearea_id: nil,
            target: target,
            target_recursion_rule: "FREQ=DAILY",
            label: "Glasses",
            created_at: Date(),
            updated_at: Date()
        )
    }

    var body: some View {
        let model = UnifiedDataModel(autoStart: false)
        let window = HabitWindow._week(Date())
        let progress = HabitProgress(current: current, target: target, targetLabel: "Glasses", window: window)
        model.habits = [habit]
        model.currentHabitProgressMap[habitID] = progress
        model.progressChartData[habitID] = [0: 3, 1: 5, 2: 2, 3: Float(current), 4: 1, 5: 0, 6: 0]

        return ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            HabitCardView(habit: habit, progress: progress, onIncrement: {})
                .environmentObject(model)
                .padding()
        }
    }
}
