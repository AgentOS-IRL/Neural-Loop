//
//  EditFleetingNoteView.swift
//  Neural Loop
//
//  Created by Codex on 16/04/2026.
//

import SwiftUI

struct EditFleetingNoteView: View {
    let note: FleetingNoteCardState
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var text: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(note: FleetingNoteCardState, onSave: @escaping (String) async throws -> Void) {
        self.note = note
        self.onSave = onSave
        _text = State(initialValue: note.note)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
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

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.errorTint)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.errorTint)
                    }

                    Spacer(minLength: 0)
                }
                .padding(AppTheme.Metrics.screenPadding)
            }
            .navigationTitle(note.source == .work ? "Edit Work Note" : "Edit Personal Note")
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
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedText.isEmpty && trimmedText != note.note && !isSaving
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

    @MainActor
    private func save() async {
        guard !trimmedText.isEmpty else {
            errorMessage = "Note content cannot be empty."
            return
        }

        errorMessage = nil
        isSaving = true

        do {
            try await onSave(trimmedText)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
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
            note: "Remember to review the notes flow.",
            timestamp: "16 Apr 2026, 10:30",
            relativeTimestamp: "Today at 10:30",
            badgeText: "Personal",
            sourceSubtitle: "Supabase"
        ),
        onSave: { _ in }
    )
}
