//
//  FleetingNotesView.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI

struct FleetingNotesView: View {
    private let manager: DBManager

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var screenState: FleetingNotesScreenState = .loading

    init(manager: DBManager = .newInstance()) {
        self.manager = manager
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: FleetingNotesTheme.Metrics.sectionSpacing) {
                        heroCard
                        content
                    }
                    .padding(.horizontal, FleetingNotesTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadNotes()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screenState {
        case .loading:
            loadingSection
        case .empty(let summary):
            messageCard(summary: summary.title, detail: summary.subtitle, systemImage: "tray")
        case .content(let content):
            VStack(alignment: .leading, spacing: FleetingNotesTheme.Metrics.cardSpacing) {
                ForEach(content.cards) { card in
                    FleetingNotesRow(card: card)
                }
            }
        case .error(let errorState):
            VStack(alignment: .leading, spacing: 16) {
                messageCard(summary: errorState.title, detail: errorState.message, systemImage: "exclamationmark.triangle")

                Button("Retry") {
                    Task {
                        await loadNotes()
                    }
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(FleetingNotesTheme.errorTint)
                )
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(FleetingNotesTheme.accentGradient)
                        .frame(width: FleetingNotesTheme.Metrics.heroIconSize, height: FleetingNotesTheme.Metrics.heroIconSize)

                    Image(systemName: "note.text")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.eyebrow.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(FleetingNotesTheme.textSecondary)

                    Text(summary.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FleetingNotesTheme.textPrimary)
                }

                Spacer(minLength: 12)
            }

            Text(summary.subtitle)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(FleetingNotesTheme.textSecondary)
        }
        .padding(24)
        .background(heroBackground)
        .overlay {
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.heroCornerRadius, style: .continuous)
                .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.heroCornerRadius, style: .continuous))
        .shadow(color: FleetingNotesTheme.glowColor.opacity(0.28), radius: 24, y: 12)
    }

    private var summary: FleetingNotesSummary {
        switch screenState {
        case .loading:
            return FleetingNotesSummary(
                eyebrow: "Fresh capture",
                title: "Loading fleeting notes",
                subtitle: "Pulling your latest short-form thoughts from Supabase."
            )
        case .empty(let summary):
            return summary
        case .content(let content):
            return content.summary
        case .error:
            return FleetingNotesSummary(
                eyebrow: "Sync problem",
                title: "Notes unavailable",
                subtitle: "The feed could not be loaded right now."
            )
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(FleetingNotesTheme.sectionGradient)
                    .frame(height: 138)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private func messageCard(summary: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FleetingNotesTheme.accentGradient)
                .padding(14)
                .background(
                    Circle()
                        .fill(FleetingNotesTheme.sectionGradient)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(summary)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(FleetingNotesTheme.textPrimary)

                Text(detail)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(FleetingNotesTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(sectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous))
    }

    private var background: some View {
        ZStack {
            FleetingNotesTheme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(FleetingNotesTheme.glowColor.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: 120, y: -260)

            Circle()
                .fill(Color.adaptive(light: Color.white.opacity(0.24), dark: Color.white.opacity(0.08)))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -140, y: -320)
        }
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.heroCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.systemBackground))
                : AnyShapeStyle(FleetingNotesTheme.heroGradient)
            )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.secondarySystemBackground))
                : AnyShapeStyle(FleetingNotesTheme.sectionGradient)
            )
    }

    @MainActor
    private func loadNotes() async {
        screenState = .loading

        do {
            let notes = try await manager.fetchFleetingNotes()
            screenState = FleetingNotesStateMapper.makeLoadedState(notes: notes)
        } catch {
            screenState = FleetingNotesStateMapper.makeErrorState(error)
        }
    }
}

#Preview {
    FleetingNotesView()
}
