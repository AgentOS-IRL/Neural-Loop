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
                        .foregroundStyle(FleetingNotesTheme.accentGradient)

                    Text(card.timestamp)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(FleetingNotesTheme.textSecondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FleetingNotesTheme.accentGradient)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(FleetingNotesTheme.sectionGradient)
                    )
            }

            Text(card.note)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(FleetingNotesTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(backgroundStyle)
        .overlay {
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 10)
    }

    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.secondarySystemBackground))
                : AnyShapeStyle(FleetingNotesTheme.cardGradient)
            )
    }
}
