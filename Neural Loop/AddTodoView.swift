//
//  AddTodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import SwiftUI

struct AddTodoView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: Int = 0

    let onSave: (TaskInput) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task")) {
                    TextField("Title", text: $title)

                    TextField(
                        "Description",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        Label("No priority", systemImage: "minus.circle")
                            .tag(0)
                        Label("Low priority", systemImage: "exclamationmark.circle")
                            .tag(1)
                        Label("Medium priority", systemImage: "exclamationmark.circle.fill")
                            .tag(2)
                        Label("High priority", systemImage: "exclamationmark.triangle.fill")
                            .tag(3)
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("New Todo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            TaskInput(
                                title: title,
                                description: description.isEmpty ? nil : description,
                                priority: priority
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
