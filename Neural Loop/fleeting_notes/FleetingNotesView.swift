//
//  FleetingNotesView.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI

struct FleetingNotesView: View {
    private let manager: DBManager
    private let workReminderService: GenesysReminderService
    let embeddedInTaskHub: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var personalNotes: [FleetingNote] = []
    @State private var workReminders: [WorkReminder] = []
    @State private var selectedFilter: FleetingNotesFilter = .all
    @State private var screenState: FleetingNotesScreenState = .loading
    @State private var workNotesWarningMessage: String?
    @State private var selectedNoteForEdit: FleetingNoteCardState?
    @State private var selectedNoteForDelete: FleetingNoteCardState?
    @State private var showDeleteConfirmation = false
    @State private var mutationErrorMessage: String?
    @State private var isMutatingNote = false

    init(
        manager: DBManager = .newInstance(),
        workReminderService: GenesysReminderService = .init(),
        embeddedInTaskHub: Bool = false
    ) {
        self.manager = manager
        self.workReminderService = workReminderService
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
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteConfirmationButtonTitle, role: .destructive) {
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
                try await updateNote(card: card, text: text)
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
        VStack(alignment: .leading, spacing: AppTheme.Metrics.cardSpacing) {
            if let workNotesWarningMessage {
                messageCard(summary: "Work notes unavailable", detail: workNotesWarningMessage, systemImage: "exclamationmark.triangle")
            }

            switch screenState {
            case .loading:
                loadingSection
            case .empty(let summary):
                filterControl
                messageCard(summary: summary.title, detail: summary.subtitle, systemImage: "tray")
            case .content(let content):
                VStack(alignment: .leading, spacing: AppTheme.Metrics.cardSpacing) {
                    filterControl

                    ForEach(content.cards) { card in
                        FleetingNotesRow(card: card)
                            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
                            .contextMenu {
                                Button {
                                    selectedNoteForEdit = card
                                } label: {
                                    Label(card.source == .work ? "Edit Work Note" : "Edit Personal Note", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    selectedNoteForDelete = card
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(card.source == .work ? "Delete Work Note" : "Delete Personal Note", systemImage: "trash")
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
    }

    private var filterControl: some View {
        Picker("Note filter", selection: $selectedFilter) {
            ForEach(FleetingNotesFilter.allCases) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedFilter) {
            rebuildScreenState()
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

    private var deleteConfirmationTitle: String {
        switch selectedNoteForDelete?.source {
        case .work:
            return "Delete this work note?"
        case .personal:
            return "Delete this personal note?"
        case nil:
            return "Delete this note?"
        }
    }

    private var deleteConfirmationButtonTitle: String {
        switch selectedNoteForDelete?.source {
        case .work:
            return "Delete Work Note"
        case .personal:
            return "Delete Personal Note"
        case nil:
            return "Delete Note"
        }
    }

    @MainActor
    private func loadNotes() async {
        screenState = .loading
        workNotesWarningMessage = nil

        async let fetchedPersonalNotes = fetchPersonalNotesResult()
        async let fetchedWorkReminders = fetchWorkRemindersResult()
        let (personalResult, workResult) = await (fetchedPersonalNotes, fetchedWorkReminders)

        switch personalResult {
        case .success(let fetchedNotes):
            personalNotes = fetchedNotes
        case .failure(let error):
            screenState = FleetingNotesStateMapper.makeErrorState(error)
            return
        }

        switch workResult {
        case .success(let fetchedReminders):
            workReminders = fetchedReminders
        case .failure(let error):
            workReminders = []
            workNotesWarningMessage = error.localizedDescription
        }

        rebuildScreenState()
        selectedNoteForEdit = nil
        selectedNoteForDelete = nil
    }

    private func fetchPersonalNotesResult() async -> Result<[FleetingNote], Error> {
        do {
            return .success(try await manager.fetchFleetingNotes())
        } catch {
            return .failure(error)
        }
    }

    private func fetchWorkRemindersResult() async -> Result<[WorkReminder], Error> {
        do {
            return .success(try await workReminderService.fetchIncompleteGenesysReminders())
        } catch {
            return .failure(error)
        }
    }

    @MainActor
    private func deleteSelectedNote() async {
        guard let selectedNoteForDelete, !isMutatingNote else { return }

        isMutatingNote = true
        defer { isMutatingNote = false }

        do {
            switch selectedNoteForDelete.source {
            case .personal:
                guard let id = selectedNoteForDelete.rawPersonalID else {
                    throw FleetingNoteMutationError.missingPersonalID
                }
                try await manager.deleteFleetingNote(id: id)
                personalNotes.removeAll { $0.id == id }
            case .work:
                guard let id = selectedNoteForDelete.rawWorkID else {
                    throw FleetingNoteMutationError.missingWorkID
                }
                try await workReminderService.deleteGenesysReminder(id: id)
                workReminders.removeAll { $0.id == id }
            }

            rebuildScreenState()
            selectedNoteForEdit = nil
            self.selectedNoteForDelete = nil
        } catch {
            mutationErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateNote(card: FleetingNoteCardState, text: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw FleetingNoteMutationError.emptyNote
        }

        switch card.source {
        case .personal:
            guard let id = card.rawPersonalID else {
                throw FleetingNoteMutationError.missingPersonalID
            }
            let updatedNote = try await manager.updateFleetingNote(
                id: id,
                request: UpdateFleetingNoteRequest(note: trimmedText)
            )

            if let index = personalNotes.firstIndex(where: { $0.id == id }) {
                personalNotes[index] = updatedNote
            } else {
                personalNotes.append(updatedNote)
            }
        case .work:
            guard let id = card.rawWorkID else {
                throw FleetingNoteMutationError.missingWorkID
            }
            let updatedReminder = try await workReminderService.updateGenesysReminder(
                id: id,
                title: trimmedText,
                notes: card.workNotes
            )

            if let index = workReminders.firstIndex(where: { $0.id == id }) {
                workReminders[index] = updatedReminder
            } else {
                workReminders.append(updatedReminder)
            }
        }

        rebuildScreenState()
    }

    @MainActor
    private func rebuildScreenState() {
        screenState = FleetingNotesStateMapper.makeLoadedState(
            personalNotes: personalNotes,
            workReminders: workReminders,
            filter: selectedFilter,
            workWarning: workNotesWarningMessage
        )
    }
}

private enum FleetingNoteMutationError: LocalizedError {
    case emptyNote
    case missingPersonalID
    case missingWorkID

    var errorDescription: String? {
        switch self {
        case .emptyNote:
            return "Note content cannot be empty."
        case .missingPersonalID:
            return "Personal note id is missing."
        case .missingWorkID:
            return "Work note id is missing."
        }
    }
}

#Preview {
    FleetingNotesView()
}
