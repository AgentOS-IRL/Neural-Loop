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
    @EnvironmentObject var model: UnifiedDataModel

    @State private var subTasks: [SubTasks] = []
    @State private var newSubTaskTitle: String = ""
    @State private var isLoading: Bool = false

    // MARK: - Async helpers

    @MainActor
    private func loadSubTasks() async {
        isLoading = true
        subTasks = await model.getSubTasks(taskId: task.id!)
        isLoading = false
    }

    @MainActor
    private func createSubTask() async {
        guard !newSubTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await model.addSubTask(newSubTaskTitle, taskId: task.id!)
        newSubTaskTitle = ""
        await loadSubTasks()
    }

    @MainActor
    private func deleteSubTask(at offsets: IndexSet) async {
        for index in offsets {
            let subtask = subTasks[index]
            await model.deleteSubTask(subtask_id: subtask.id)
        }
        await loadSubTasks()
    }

    @MainActor
    private func toggleSubTask(_ subTask: SubTasks) async {
        await model.setSubTaskIsCompleted(
            subtask_id: subTask.id,
            is_completed: !subTask.is_completed
        )
        await loadSubTasks()
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            List {
                // MARK: Task Overview
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.title)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            Image(systemName: task.is_completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.is_completed ? .green : .secondary)
                        }

                        if let description = task.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Priority", systemImage: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(priorityText)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Subtasks
                Section("Subtasks") {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if subTasks.isEmpty {
                        Text("No subtasks yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(subTasks) { subTask in
                            Button {
                                Task {
                                    await toggleSubTask(subTask)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: subTask.is_completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(subTask.is_completed ? .green : .secondary)

                                    Text(subTask.title)
                                        .strikethrough(subTask.is_completed)
                                        .foregroundStyle(subTask.is_completed ? .secondary : .primary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                await deleteSubTask(at: offsets)
                            }
                        }
                    }
                }

                // MARK: Add Subtask
                Section {
                    HStack {
                        TextField("New subtask", text: $newSubTaskTitle)
                            .textInputAutocapitalization(.sentences)

                        Button {
                            Task {
                                await createSubTask()
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newSubTaskTitle.isEmpty)
                    }
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
            .task {
                await loadSubTasks()
            }
        }
    }

    // MARK: - Derived values

    private var priorityText: String {
        switch task.priority {
        case 0: return "Low"
        case 1: return "Medium"
        case 2: return "High"
        case 3: return "Critical"
        default: return "Unknown"
        }
    }
}
