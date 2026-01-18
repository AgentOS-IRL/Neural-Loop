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

    /// Use a stable, Equatable value for animation (Dictionary isn't Equatable)
    private var animationValues: [Float] {
        keys.map { values[$0] ?? 0 }
    }

    private var maxValue: CGFloat {
        switch HabitWindow.get_frequency(for: habit){
        case .daily: return CGFloat(habit.target)
        default: return CGFloat(1)
        }
    }
    
    private func getValue(_ key: Int) -> CGFloat {
        min(CGFloat(values[key] ?? 0), maxValue)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(items) { item in
                DayBarColumn(
                    key: item.id,
                    label: item.label,
                    rawValue: getValue(item.id),
                    maxValue: maxValue
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: animationValues)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
}

private struct DayBarColumn: View {
    let key: Int
    let label: String
    let rawValue: CGFloat
    let maxValue: CGFloat

    private var normalized: CGFloat {
        let safeMax = max(maxValue, 1)
        return min(max(rawValue / safeMax, 0), 1)
    }

    let todayIndex = (Calendar.current.component(.weekday, from: .now) + 5) % 7
    
    private var isToday: Bool { key == todayIndex }
    
    
    

    var body: some View {
        
        VStack(spacing: 8) {
            ModernBar(progress: normalized,rawValue: rawValue,  highlight: isToday)
                .frame(height: 44)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text("\(Int(rawValue))"))

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(isToday ? Color.primary.opacity(0.10) : Color.clear)
                )
        }
    }
}

private struct ModernBar: View {
    let progress: CGFloat          // 0...1
    let rawValue: CGFloat
    let highlight: Bool
    

    private var gradient: LinearGradient {
        let top = highlight ? Color.accentColor : Color.accentColor.opacity(0.90)
        let bottom = highlight ? Color.accentColor.opacity(0.55) : Color.accentColor.opacity(0.35)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height
            let fillHeight = max(4, fullHeight * progress)
            
            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.08))

                // Fill
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(gradient)
                    .frame(height: fillHeight)
                    .overlay(alignment: .top) {
                        // Subtle shine
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(highlight ? 0.18 : 0.10))
                            .frame(height: 10)
                            .blendMode(.plusLighter)
                            .padding(.top, 2)
                            .opacity(progress > 0.05 ? 1 : 0)
                    }// 🔤 Text INSIDE bar (only when tall enough)
                    .overlay(alignment: .center) {
                        if progress >= 0.5 {
                            Text("\(Int(rawValue))")
                                .font(highlight ? .caption.bold() :.caption2 )
                                .foregroundStyle(highlight ? .white : .secondary)
                        }
                    }

                // 🔤 Text ABOVE bar (only when bar is short)
                if progress < 0.5 {
                    Text("\(Int(rawValue))")
                        .font(highlight ? .caption.bold() : .caption2 )
                        .foregroundStyle(highlight ? .white : .secondary)
                        .padding(.bottom, fillHeight + 4)
                }

                // Tiny cap for "active" feel
                if highlight && progress > 0.15 {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 10, height: 10)
                        .padding(.bottom, fillHeight - 8)
                        .blendMode(.plusLighter)
                }
            }
        }
    }
}
