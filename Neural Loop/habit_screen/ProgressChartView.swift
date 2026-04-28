//
//  WeekBarView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 18/01/2026.
//

import SwiftUI

struct ProgressChartView: View {
    let habit: Habits
    let values: [Int: Float]

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]
    private let keys = Array(0...6)

    private struct WeekDayItem: Identifiable {
        let id: Int
        let label: String
    }

    private var items: [WeekDayItem] {
        Array(zip(keys, labels)).map { WeekDayItem(id: $0.0, label: $0.1) }
    }

    private var animationValues: [Float] {
        keys.map { values[$0] ?? 0 }
    }

    private var maxValue: CGFloat {
        switch HabitWindow.get_frequency(for: habit) {
        case .daily: return CGFloat(habit.target)
        default: return CGFloat(1)
        }
    }
    
    private func getValue(_ key: Int) -> CGFloat {
        min(CGFloat(values[key] ?? 0), maxValue)
    }
    
    private var todayIndex: Int {
        let calendar = Calendar.neuralLoopDisplay
        // Convert 1-indexed weekday (1=Sun, 2=Mon...) to 0-indexed (0=Mon, 6=Sun)
        let weekday = calendar.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }
    
    private func dateFor(_ key: Int) -> Date {
        let calendar = Calendar.neuralLoopDisplay
        let diff = key - todayIndex
        return calendar.date(byAdding: .day, value: diff, to: Date()) ?? Date()
    }

    private func isOccurring(_ key: Int) -> Bool {
        return HabitWindow.isOccurring(on: dateFor(key), habit: habit)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(items) { item in
                DayBarColumn(
                    key: item.id,
                    label: item.label,
                    rawValue: getValue(item.id),
                    maxValue: maxValue,
                    isOccurring: isOccurring(item.id),
                    todayIndex: todayIndex
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animationValues)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
    }
}

private struct DayBarColumn: View {
    let key: Int
    let label: String
    let rawValue: CGFloat
    let maxValue: CGFloat
    let isOccurring: Bool
    let todayIndex: Int

    private var normalized: CGFloat {
        if !isOccurring && rawValue == 0 { return 0 }
        let safeMax = max(maxValue, 1)
        return min(max(rawValue / safeMax, 0), 1)
    }

    private var isToday: Bool { key == todayIndex }
    private var isCompleted: Bool { normalized >= 1.0 }

    /// Days away from today (0 = today, 1 = yesterday/tomorrow, …)
    private var distance: Int { abs(key - todayIndex) }

    /// Horizontal inset applied to the bar — further days are visually narrower
    private var barInset: CGFloat {
        switch distance {
        case 0: return 0
        case 1: return 3
        case 2: return 6
        default: return 9
        }
    }

    /// Opacity applied to the bar — further days fade out
    private var barOpacity: Double {
        switch distance {
        case 0: return 1.0
        case 1: return 0.70
        case 2: return 0.50
        default: return 0.32
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ModernBar(
                progress: normalized,
                rawValue: rawValue,
                highlight: isToday,
                isOccurring: isOccurring,
                isCompleted: isCompleted
            )
            .frame(height: 120)
            .padding(.horizontal, barInset)
            .opacity(barOpacity)
            .accessibilityLabel("\(label) progress")
            .accessibilityValue("\(Int(rawValue)) of \(Int(maxValue))")

            Text(label)
                .font(.system(size: 10, weight: distance == 0 ? .black : .bold, design: .rounded))
                .foregroundStyle(isToday ? .primary : .secondary)
                .opacity(barOpacity + 0.2) // labels stay slightly more visible than bars
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(isToday ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
    }
}

private struct ModernBar: View {
    let progress: CGFloat
    let rawValue: CGFloat
    let highlight: Bool
    let isOccurring: Bool
    let isCompleted: Bool
    
    private var barGradient: LinearGradient {
        if !isOccurring && rawValue == 0 {
            return LinearGradient(
                colors: [.secondary.opacity(0.1), .secondary.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        let accent = Color.accentColor
        let topColor = isCompleted ? accent : accent.opacity(0.9)
        let bottomColor = isCompleted ? accent.opacity(0.7) : accent.opacity(0.4)
        
        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height
            let fillHeight = max(isCompleted ? fullHeight : 0, fullHeight * progress)
            
            ZStack(alignment: .bottom) {
                // Background Track
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOccurring ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                    .overlay {
                        if !isOccurring {
                            DashedBorder(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        }
                    }

                // Fill
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(barGradient)
                    .frame(height: fillHeight)
                    .shadow(color: highlight ? Color.accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 0)
                    .overlay(alignment: .top) {
                        // Gloss/Shine effect
                        if progress > 0.1 {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(highlight ? 0.25 : 0.15))
                                .frame(height: 8)
                                .padding(2)
                                .blur(radius: 1)
                        }
                    }
                    .overlay(alignment: .center) {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        } else if progress > 0.3 {
                            Text("\(Int(rawValue))")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                // Above bar text for low progress
                if !isCompleted && progress <= 0.3 && rawValue > 0 {
                    Text("\(Int(rawValue))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(highlight ? .primary : .secondary)
                        .padding(.bottom, fillHeight + 4)
                }
            }
        }
    }
}

private struct DashedBorder: Shape {
    let cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}
