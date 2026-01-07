//
//  EditTodoView.swift
//  Neural Loop
//
//  Created by Codex on 07/01/2026.
//

import SwiftUI

struct EditTodoView: View {
    let task: Tasks
    let onSave: (String, String?, Bool) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var isCompleted: Bool
    @State private var showDeleteConfirm: Bool = false

    init(task: Tasks, onSave: @escaping (String, String?, Bool) -> Void, onDelete: @escaping () -> Void) {
        self.task = task
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description ?? "")
        _isCompleted = State(initialValue: task.is_completed)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                TextField("Task title", text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 8)

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Description")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }

                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .padding(.horizontal, -4)
                }

                Toggle("Completed", isOn: $isCompleted)
                    .padding(.top, 8)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                Spacer()
                Button {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(trimmedTitle, trimmedDesc.isEmpty ? nil : trimmedDesc, isCompleted)
                    dismiss()
                } label: {
                    HStack {
                        Text("Save")
                        Image(systemName: "checkmark")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(
                                title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1
                            ))
                    )
                    .foregroundColor(.white)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete this task?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}
