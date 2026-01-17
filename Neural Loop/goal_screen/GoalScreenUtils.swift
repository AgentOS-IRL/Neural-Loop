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
                .fill(Color.gray.opacity(0.15))

            Capsule()
                .fill(Color.blue.opacity(0.6))
                .frame(width: 30 * clamped)
        }
        .frame(width: 30, height: 10)

        Text("\(Int(clamped * 100))%")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}


func topButton(
    title: String,
    isSelected: Bool,
    action: @escaping () -> Void
) ->  some View {
    Button(action: action) {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.primary
                        : Color(.secondarySystemBackground)
                    )
            )
    }
    .buttonStyle(.plain)
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

    let clampedSize = size.clamped(to: 16...36)
    let containerSize = clampedSize * 1.5
    let iconSize = clampedSize * 0.8
    let cornerRadius = containerSize * 0.28

    return HStack(spacing: containerSize * 0.35) {

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.systemGray5))

            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .frame(width: containerSize, height: containerSize)

        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
                .foregroundColor(.primary)
            
            additionalContent()
            if let subText {
                Text(subText)
                    .font(.subheadline)
                                        .foregroundColor(.secondary)
            }
        }
    }
}
