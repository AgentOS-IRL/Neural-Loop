//
//  EditFleetingNoteView.swift
//  Neural Loop
//
//  Created by Codex on 16/04/2026.
//

import SwiftUI

struct EditFleetingNoteView: View {
    let note: FleetingNoteCardState?
    let existingAttachments: [ImageAttachment]
    let availableTasks: [Tasks]
    let initialTaskID: Int64?
    let onSave: (String, [ImageAttachment], Int64?) async throws -> Void

    init(
        note: FleetingNoteCardState? = nil,
        existingAttachments: [ImageAttachment] = [],
        availableTasks: [Tasks] = [],
        initialTaskID: Int64? = nil,
        onSave: @escaping (String, [ImageAttachment], Int64?) async throws -> Void
    ) {
        self.note = note
        self.existingAttachments = existingAttachments
        self.availableTasks = availableTasks
        self.initialTaskID = initialTaskID
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            FleetingNoteEditorContent(
                note: note,
                existingAttachments: existingAttachments,
                availableTasks: availableTasks,
                initialTaskID: initialTaskID,
                onSave: onSave
            )
        }
    }
}

struct FleetingNoteEditorContent: View {
    let note: FleetingNoteCardState?
    let availableTasks: [Tasks]
    let onSave: (String, [ImageAttachment], Int64?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var text: String
    @State private var errorMessage: String?
    @State private var attachments: [ImageAttachment]
    @State private var selectedTaskID: Int64?
    @State private var isSaving = false

    private let initialText: String
    private let initialAttachments: [ImageAttachment]
    private let initialTaskID: Int64?

    init(
        note: FleetingNoteCardState? = nil,
        existingAttachments: [ImageAttachment] = [],
        availableTasks: [Tasks] = [],
        initialTaskID: Int64? = nil,
        onSave: @escaping (String, [ImageAttachment], Int64?) async throws -> Void
    ) {
        let resolvedTaskID = initialTaskID ?? note?.linkedTaskID
        self.note = note
        self.availableTasks = availableTasks
        self.onSave = onSave
        self.initialText = note?.note ?? ""
        self.initialAttachments = existingAttachments
        self.initialTaskID = resolvedTaskID
        _text = State(initialValue: note?.note ?? "")
        _attachments = State(initialValue: existingAttachments)
        _selectedTaskID = State(initialValue: resolvedTaskID)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .frame(minHeight: 220)
                        .background(editorBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))

                    if supportsPersonalNoteFeatures {
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Context")
                            ThemedCard {
                                NavigationLink {
                                    TaskPickerView(
                                        tasks: availableTasks,
                                        selectedTaskID: $selectedTaskID
                                    )
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundStyle(AppTheme.accentColor)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Linked task")
                                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                                .foregroundStyle(AppTheme.textSecondary)

                                            Text(selectedTask?.title ?? "No linked task")
                                                .font(.system(.body, design: .rounded, weight: .semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Attachments")
                            ThemedCard {
                                ImageAttachmentSection(attachments: $attachments)
                            }
                        }
                    }

                    if let validationMessage {
                        validationText(validationMessage)
                    }

                    if let errorMessage {
                        validationText(errorMessage)
                    }
                }
                .padding(AppTheme.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(saveButtonTitle)
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!canSave)
            }
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedTask: Tasks? {
        guard let selectedTaskID else { return nil }
        return availableTasks.first { $0.id == selectedTaskID }
    }

    private var supportsPersonalNoteFeatures: Bool {
        note == nil || note?.source == .personal
    }

    private var canSave: Bool {
        let textChanged = trimmedText != initialText
        let attachmentsChanged = attachments != initialAttachments
        let taskChanged = supportsPersonalNoteFeatures && selectedTaskID != initialTaskID
        return !trimmedText.isEmpty && (textChanged || attachmentsChanged || taskChanged) && !isSaving
    }

    private var validationMessage: String? {
        guard trimmedText.isEmpty else { return nil }
        return "Note content cannot be empty."
    }

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.secondarySystemBackground))
                : AnyShapeStyle(AppTheme.sectionGradient)
            )
    }

    private var navigationTitle: String {
        switch note?.source {
        case .work:
            return "Edit Work Note"
        case .personal:
            return "Edit Personal Note"
        case nil:
            return "New Personal Note"
        }
    }

    private var saveButtonTitle: String {
        note == nil ? "Create" : "Save"
    }

    private func validationText(_ value: String) -> some View {
        Text(value)
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.errorTint)
    }

    @MainActor
    private func save() async {
        guard !trimmedText.isEmpty else {
            errorMessage = "Note content cannot be empty."
            return
        }

        errorMessage = nil
        isSaving = true

        do {
            try await onSave(
                trimmedText,
                attachments,
                supportsPersonalNoteFeatures ? selectedTaskID : nil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private struct TaskPickerView: View {
    let tasks: [Tasks]
    @Binding var selectedTaskID: Int64?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                taskChoice(title: "No linked task", taskID: nil, systemImage: "link.badge.minus")
            }

            if searchText.isEmpty {
                taskSection("Today", tasks: todayTasks)
                taskSection("Upcoming", tasks: upcomingTasks)
                taskSection("Inbox", tasks: inboxTasks)
            } else if searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                Section("Results") {
                    ForEach(searchResults) { task in
                        taskChoice(task: task)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Link Task")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks")
    }

    @ViewBuilder
    private func taskSection(_ title: String, tasks: [Tasks]) -> some View {
        if !tasks.isEmpty {
            Section(title) {
                ForEach(tasks) { task in
                    taskChoice(task: task)
                }
            }
        }
    }

    private func taskChoice(task: Tasks) -> some View {
        Button {
            selectedTaskID = task.id
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedTaskID == task.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTaskID == task.id ? AppTheme.accentColor : AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .foregroundStyle(AppTheme.textPrimary)

                    if task.is_completed {
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    private func taskChoice(title: String, taskID: Int64?, systemImage: String) -> some View {
        Button {
            selectedTaskID = taskID
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedTaskID == taskID ? "checkmark.circle.fill" : systemImage)
                    .foregroundStyle(selectedTaskID == taskID ? AppTheme.accentColor : AppTheme.textSecondary)
                Text(title)
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    private var searchableTasks: [Tasks] {
        tasks
            .filter { $0.id != nil }
            .sorted { lhs, rhs in
                let lhsDate = lhs.start_date ?? .distantFuture
                let rhsDate = rhs.start_date ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhsDate < rhsDate
            }
    }

    private var incompleteTasks: [Tasks] {
        searchableTasks.filter { !$0.is_completed }
    }

    private var todayTasks: [Tasks] {
        incompleteTasks.filter { task in
            task.start_date.map(Calendar.current.isDateInToday) ?? false
        }
    }

    private var upcomingTasks: [Tasks] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return incompleteTasks.filter { ($0.start_date ?? .distantPast) >= tomorrow }
    }

    private var inboxTasks: [Tasks] {
        let todayIDs = Set(todayTasks.compactMap(\.id))
        let upcomingIDs = Set(upcomingTasks.compactMap(\.id))
        return incompleteTasks.filter { task in
            guard let id = task.id else { return false }
            return !todayIDs.contains(id) && !upcomingIDs.contains(id)
        }
    }

    private var searchResults: [Tasks] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return searchableTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query)
            || (task.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}

#Preview {
    EditFleetingNoteView(
        note: FleetingNoteCardState(
            id: "personal-1",
            source: .personal,
            rawPersonalID: 1,
            rawWorkID: nil,
            workNotes: nil,
            note: "Remember to review the notes flow.",
            timestamp: "16 Apr 2026, 10:30",
            relativeTimestamp: "Today at 10:30",
            badgeText: "Personal",
            sourceSubtitle: "Supabase",
            linkedTaskID: 42,
            linkedTaskTitle: "Review notes flow"
        ),
        onSave: { _, _, _ in }
    )
}
