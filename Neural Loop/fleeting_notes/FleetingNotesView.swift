//
//  FleetingNotesView.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI

struct FleetingNotesView: View {
    private let manager: DBManager
    let embeddedInTaskHub: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var notes: [FleetingNote] = []
    @State private var screenState: FleetingNotesScreenState = .loading
    @State private var selectedNoteForEdit: FleetingNoteCardState?
    @State private var selectedNoteForDelete: FleetingNoteCardState?
    @State private var showDeleteConfirmation = false
    @State private var mutationErrorMessage: String?
    @State private var isMutatingNote = false

    init(manager: DBManager = .newInstance(), embeddedInTaskHub: Bool = false) {
        self.manager = manager
        self.embeddedInTaskHub = embeddedInTaskHub
    }

    var body: some View {
        Group {
            if embeddedInTaskHub {
                notesRootContent
            } else {
                NavigationStack {
                    notesRootContent
                        .navigationTitle("Notes")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .task {
            await loadNotes()
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Note", role: .destructive) {
                Task {
                    await deleteSelectedNote()
                }
            }
            .disabled(isMutatingNote)

            Button("Cancel", role: .cancel) {
                selectedNoteForDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $selectedNoteForEdit) { card in
            EditFleetingNoteView(note: card) { text in
                try await updateNote(id: card.id, text: text)
            }
        }
        .alert(
            "Note action failed",
            isPresented: Binding(
                get: { mutationErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        mutationErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                mutationErrorMessage = nil
            }
        } message: {
            Text(mutationErrorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var notesRootContent: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                    if embeddedInTaskHub {
                        notesEmbeddedHeader
                    } else {
                        heroCard
                    }

                    content
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, bottomContentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch screenState {
        case .loading:
            loadingSection
        case .empty(let summary):
            messageCard(summary: summary.title, detail: summary.subtitle, systemImage: "tray")
        case .content(let content):
            VStack(alignment: .leading, spacing: AppTheme.Metrics.cardSpacing) {
                ForEach(content.cards) { card in
                    FleetingNotesRow(card: card)
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
                        .contextMenu {
                            Button {
                                selectedNoteForEdit = card
                            } label: {
                                Label("Edit Note", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                selectedNoteForDelete = card
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Note", systemImage: "trash")
                            }
                        }
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
                        .fill(AppTheme.errorTint)
                )
            }
        }
    }

    private var notesEmbeddedHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Capture short thoughts before they become tasks.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(20)
        .background(AppTheme.heroGradient)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .cornerRadius(AppTheme.Metrics.cardCornerRadius)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                        .frame(width: AppTheme.Metrics.heroIconSize, height: AppTheme.Metrics.heroIconSize)

                    Image(systemName: "note.text")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.eyebrow.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(summary.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer(minLength: 12)
            }

            Text(summary.subtitle)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(24)
        .background(heroBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous))
        .shadow(color: AppTheme.glowColor.opacity(0.28), radius: 24, y: 12)
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
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.sectionGradient)
                    .frame(height: 138)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private func messageCard(summary: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentGradient)
                .padding(14)
                .background(
                    Circle()
                        .fill(AppTheme.sectionGradient)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(summary)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(detail)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(sectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
    }

    private var background: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(AppTheme.glowColor.opacity(0.20))
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
        RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.systemBackground))
                : AnyShapeStyle(AppTheme.heroGradient)
            )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.secondarySystemBackground))
                : AnyShapeStyle(AppTheme.sectionGradient)
            )
    }

    private var bottomContentPadding: CGFloat {
        embeddedInTaskHub ? SAFE_AREA_INSET + 104 : 120
    }

    @MainActor
    private func loadNotes() async {
        screenState = .loading

        do {
            let fetchedNotes = try await manager.fetchFleetingNotes()
            notes = fetchedNotes
            screenState = FleetingNotesStateMapper.makeLoadedState(notes: fetchedNotes)
            selectedNoteForEdit = nil
            selectedNoteForDelete = nil
        } catch {
            screenState = FleetingNotesStateMapper.makeErrorState(error)
        }
    }

    @MainActor
    private func deleteSelectedNote() async {
        guard let selectedNoteForDelete, !isMutatingNote else { return }

        isMutatingNote = true
        defer { isMutatingNote = false }

        do {
            try await manager.deleteFleetingNote(id: selectedNoteForDelete.id)
            notes.removeAll { $0.id == selectedNoteForDelete.id }
            rebuildScreenState()
            self.selectedNoteForDelete = nil
        } catch {
            mutationErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateNote(id: Int64, text: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw FleetingNoteMutationError.emptyNote
        }

        let updatedNote = try await manager.updateFleetingNote(
            id: id,
            request: UpdateFleetingNoteRequest(note: trimmedText)
        )

        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index] = updatedNote
        } else {
            notes.append(updatedNote)
        }

        rebuildScreenState()
    }

    @MainActor
    private func rebuildScreenState() {
        screenState = FleetingNotesStateMapper.makeLoadedState(notes: notes)
    }
}

private enum FleetingNoteMutationError: LocalizedError {
    case emptyNote

    var errorDescription: String? {
        switch self {
        case .emptyNote:
            return "Note content cannot be empty."
        }
    }
}

#Preview {
    FleetingNotesView()
}
