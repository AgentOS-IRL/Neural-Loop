//
//  GoalScreenUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 12/01/2026.
//
import SwiftUI

func progressMiniBar(percentage: Double) -> some View {
    let clamped = min(max(percentage, 0), 1)

    return HStack(spacing: 6) {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppTheme.sectionGradient)

            Capsule()
                .fill(AppTheme.accentGradient)
                .frame(width: 30 * clamped)
        }
        .frame(width: 30, height: 10)

        Text("\(Int(clamped * 100))%")
            .font(.system(.caption, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

func iconTitle<AdditionalContent: View>(
    icon: String,
    name: String,
    size: CGFloat = 22,
    subText: String? = nil,
    @ViewBuilder additionalContent: () -> AdditionalContent = { EmptyView() }
) -> some View {

    let clampedSize = size.clamped(to: 16...56)
    let containerSize = clampedSize * 1.5
    let iconSize = clampedSize * 0.8
    let cornerRadius = containerSize * 0.28

    return HStack(spacing: containerSize * 0.35) {

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)

            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(width: containerSize, height: containerSize)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.borderGradient, lineWidth: 1)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            additionalContent()
            if let subText {
                Text(subText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
}
