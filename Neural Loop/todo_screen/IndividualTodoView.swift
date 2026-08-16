//
//  IndividualTodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 17/01/2026.
//

import SwiftUI

struct IndividualTodoView: View {
    let task: Tasks

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: UnifiedDataModel
    @StateObject private var viewModel = IndividualTodoViewModel()

    @State private var noteEditorRoute: TaskNoteEditorRoute?
    @State private var editorAttachments: [ImageAttachment] = []
    @State private var selectedNoteForDelete: FleetingNote?
    @State private var showAllNotes = false
    @State private var isMutatingNote = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        overviewSection
                        notesSection
                        subtasksSection
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await loadDetail()
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $noteEditorRoute) { route in
                noteEditorDestination(route)
            }
            .confirmationDialog(
                "Delete this personal note?",
                isPresented: Binding(
                    get: { selectedNoteForDelete != nil },
                    set: { if !$0 { selectedNoteForDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Personal Note", role: .destructive) {
                    Task {
                        await deleteSelectedNote()
                    }
                }
                Button("Cancel", role: .cancel) {
                    selectedNoteForDelete = nil
                }
            } message: {
                Text("The note and its attachments will be permanently removed.")
            }
            .alert(
                "Task Detail",
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { if !$0 { viewModel.alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.alertMessage = nil
                }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .task {
                await loadDetail()
            }
        }
    }

    private var currentTask: Tasks {
        guard let id = task.id else { return task }
        return model.getTask(by: id) ?? task
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            themedSectionHeader("Overview")

            ThemedCard(gradient: AppTheme.heroGradient) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentTask.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        if let description = currentTask.description, !description.isEmpty {
                            Text(description)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer(minLength: 12)

                    Image(systemName: currentTask.is_completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(currentTask.is_completed ? AppTheme.successTint : AppTheme.textSecondary)
                }

                HStack(spacing: 8) {
                    Label(priorityText, systemImage: "flag.fill")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.accentColor.opacity(0.12), in: Capsule())

                    if let startDate = currentTask.start_date {
                        Label(startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                themedSectionHeader("Notes")
                Spacer()
                Button {
                    editorAttachments = []
                    noteEditorRoute = .create
                } label: {
                    Label("Add note", systemImage: "plus")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .disabled(task.id == nil || isMutatingNote)
            }

            ThemedCard {
                if viewModel.isLoadingNotes {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.notes.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accentColor)
                        Text("No notes for this task yet")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Capture context, decisions, or follow-up details here.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Add note") {
                            editorAttachments = []
                            noteEditorRoute = .create
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(Array(visibleNotes.enumerated()), id: \.element.id) { index, note in
                        if index > 0 {
                            Divider()
                        }
                        taskNoteRow(note)
                    }

                    if viewModel.notes.count > 3 {
                        Divider()
                        Button(showAllNotes ? "Show latest three" : "View all \(viewModel.notes.count) notes") {
                            withAnimation(.easeInOut) {
                                showAllNotes.toggle()
                            }
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            themedSectionHeader("Subtasks")

            ThemedCard {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.subTasks.isEmpty {
                    Text("No subtasks yet")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(Array(viewModel.subTasks.enumerated()), id: \.element.id) { index, subTask in
                        if index > 0 {
                            Divider()
                        }

                        Button {
                            Task {
                                await viewModel.toggleSubTask(subTask, from: model, taskId: task.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: subTask.is_completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(subTask.is_completed ? AppTheme.successTint : AppTheme.textSecondary)
                                Text(subTask.title)
                                    .strikethrough(subTask.is_completed)
                                    .foregroundStyle(subTask.is_completed ? AppTheme.textSecondary : AppTheme.textPrimary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    guard let index = viewModel.subTasks.firstIndex(where: { $0.id == subTask.id }) else { return }
                                    await viewModel.deleteSubTask(at: IndexSet(integer: index), from: model, taskId: task.id)
                                }
                            } label: {
                                Label("Delete Subtask", systemImage: "trash")
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    TextField("New subtask", text: $viewModel.newSubTaskTitle)
                        .textInputAutocapitalization(.sentences)
                        .foregroundStyle(AppTheme.textPrimary)

                    Button {
                        Task {
                            await viewModel.createSubTask(from: model, taskId: task.id)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(!viewModel.canAddSubTask || task.id == nil)
                }
            }
        }
    }

    private var visibleNotes: [FleetingNote] {
        showAllNotes ? viewModel.notes : Array(viewModel.notes.prefix(3))
    }

    private func taskNoteRow(_ note: FleetingNote) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Task {
                    await openEditor(for: note)
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.note)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text(note.created_at.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit Note", systemImage: "pencil") {
                    Task {
                        await openEditor(for: note)
                    }
                }
                Button("Unlink from Task", systemImage: "link.badge.minus") {
                    Task {
                        await unlink(note)
                    }
                }
                Button(role: .destructive) {
                    selectedNoteForDelete = note
                } label: {
                    Label("Delete Note", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(6)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func noteEditorDestination(_ route: TaskNoteEditorRoute) -> some View {
        switch route {
        case .create:
            FleetingNoteEditorContent(
                availableTasks: model.tasks,
                initialTaskID: task.id
            ) { text, attachments, selectedTaskID in
                guard let createdNote = await model.saveFleetingNote(
                    CreateFleetingNoteRequest(note: text, task_id: selectedTaskID)
                ) else {
                    throw TaskNoteMutationError.saveFailed
                }
                await model.saveImageAttachments(attachments, forFleetingNoteId: createdNote.id)
                await viewModel.loadNotes(from: model, taskId: task.id)
            }

        case .edit(let noteID):
            if let note = viewModel.notes.first(where: { $0.id == noteID }) {
                FleetingNoteEditorContent(
                    note: editorCard(for: note),
                    existingAttachments: editorAttachments,
                    availableTasks: model.tasks
                ) { text, attachments, selectedTaskID in
                    guard await model.updateFleetingNote(
                        id: note.id,
                        request: UpdateFleetingNoteRequest(note: text, task_id: selectedTaskID)
                    ) != nil else {
                        throw TaskNoteMutationError.saveFailed
                    }
                    await model.replaceImageAttachments(attachments, forFleetingNoteId: note.id)
                    await viewModel.loadNotes(from: model, taskId: task.id)
                }
            } else {
                ContentUnavailableView("Note unavailable", systemImage: "note.text")
            }
        }
    }

    private func editorCard(for note: FleetingNote) -> FleetingNoteCardState {
        FleetingNoteCardState(
            id: "personal-\(note.id)",
            source: .personal,
            rawPersonalID: note.id,
            rawWorkID: nil,
            workNotes: nil,
            note: note.note,
            timestamp: note.created_at.formatted(date: .abbreviated, time: .shortened),
            relativeTimestamp: note.created_at.formatted(date: .abbreviated, time: .shortened),
            badgeText: "Personal",
            sourceSubtitle: "Supabase",
            linkedTaskID: note.task_id,
            linkedTaskTitle: note.task_id.flatMap { model.getTask(by: $0)?.title }
        )
    }

    @MainActor
    private func loadDetail() async {
        await viewModel.loadSubTasks(from: model, taskId: task.id)
        await viewModel.loadNotes(from: model, taskId: task.id)
    }

    @MainActor
    private func openEditor(for note: FleetingNote) async {
        editorAttachments = await model.fetchImageAttachments(forFleetingNoteId: note.id)
        noteEditorRoute = .edit(note.id)
    }

    @MainActor
    private func unlink(_ note: FleetingNote) async {
        guard !isMutatingNote else { return }
        isMutatingNote = true
        defer { isMutatingNote = false }

        guard await model.updateFleetingNote(
            id: note.id,
            request: UpdateFleetingNoteRequest(note: note.note, task_id: nil)
        ) != nil else {
            viewModel.alertMessage = TaskNoteMutationError.saveFailed.localizedDescription
            return
        }

        await viewModel.loadNotes(from: model, taskId: task.id)
    }

    @MainActor
    private func deleteSelectedNote() async {
        guard let note = selectedNoteForDelete, !isMutatingNote else { return }
        isMutatingNote = true
        defer { isMutatingNote = false }

        guard await model.deleteFleetingNote(id: note.id) else {
            viewModel.alertMessage = TaskNoteMutationError.deleteFailed.localizedDescription
            return
        }

        selectedNoteForDelete = nil
        await viewModel.loadNotes(from: model, taskId: task.id)
    }

    private var priorityText: String {
        switch currentTask.priority {
        case 0: return "Low"
        case 1: return "Medium"
        case 2: return "High"
        case 3: return "Critical"
        default: return "Unknown"
        }
    }
}

private enum TaskNoteEditorRoute: Hashable, Identifiable {
    case create
    case edit(Int64)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let id): return "edit-\(id)"
        }
    }
}

private enum TaskNoteMutationError: LocalizedError {
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "The note could not be saved. Please try again."
        case .deleteFailed:
            return "The note could not be deleted. Please try again."
        }
    }
}
