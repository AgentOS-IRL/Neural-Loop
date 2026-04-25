//
//  FleetingNotesRow.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI

struct FleetingNotesRow: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let card: FleetingNoteCardState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.relativeTimestamp)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.accentGradient)

                    Text(card.timestamp)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(card.sourceSubtitle)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 12)

                sourceBadge
            }

            Text(card.note)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(backgroundStyle)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 10)
    }

    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.secondarySystemBackground))
                : AnyShapeStyle(AppTheme.cardGradient)
            )
    }

    private var sourceBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: card.source == .work ? "briefcase.fill" : "sparkles")
                .font(.system(size: 11, weight: .semibold))

            Text(card.badgeText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(sourceTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(sourceTint.opacity(0.14))
        )
        .overlay {
            Capsule()
                .strokeBorder(sourceTint.opacity(0.24), lineWidth: 1)
        }
    }

    private var sourceTint: Color {
        switch card.source {
        case .personal:
            return AppTheme.accentColor
        case .work:
            return AppTheme.workEventTint
        }
    }
}
