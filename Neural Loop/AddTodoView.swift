//
//  AddTodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import SwiftUI
import EventKit

struct AddTodoView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: Int = 0
    
    @State private var showScheduleSheet = false
    @State private var scheduleDraft: TaskScheduleDraft?

    let onSave: (TaskInput) -> Void

    private var priorityIcon: String {
        switch priority {
        case 1: return "exclamationmark.circle"
        case 2: return "exclamationmark.circle.fill"
        case 3: return "exclamationmark.triangle.fill"
        default: return "minus.circle"
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal)

            // Content
            VStack(alignment: .leading, spacing: 12) {

                TextField("New task", text: $title)
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

                Spacer(minLength: 16)

                // Bottom actions row
                HStack(spacing: 20) {

                    Spacer()

                    Image(systemName: "clock")
                    Image(systemName: "flag").onTapGesture {
                        showScheduleSheet = true
                    }
                    Image(systemName: "tag")
                    Image(systemName: priorityIcon)
                        .foregroundColor(priority == 0 ? .secondary : .accentColor)
                        .onTapGesture {
                            priority = (priority + 1) % 4
                        }

                }
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .sheet(isPresented: $showScheduleSheet) {
                    TaskScheduleSheet { draft in
                        scheduleDraft = draft
                        print("📅 TaskScheduleDraft returned:")
                        print("Summary:", draft.recurrence?.summary() ?? "No Recurrence")
                               
                    }
                }
            }
            .padding()

            Divider()

            // Footer
            HStack {

                Label("Select goal or life area", systemImage: "scope")
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    onSave(
                        TaskInput(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            priority: priority
                        )
                    )
                    dismiss()
                } label: {
                    HStack {
                        Text("Create")
                        Image(systemName: "plus")
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
    }
}
