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

    @StateObject private var viewModel = IndividualTodoViewModel()

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
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.subTasks.isEmpty {
                        Text("No subtasks yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.subTasks) { subTask in
                            Button {
                                Task {
                                    await viewModel.toggleSubTask(
                                        subTask,
                                        from: model,
                                        taskId: task.id
                                    )
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
                                await viewModel.deleteSubTask(
                                    at: offsets,
                                    from: model,
                                    taskId: task.id
                                )
                            }
                        }
                    }
                }

                // MARK: Add Subtask
                Section {
                    HStack {
                        TextField("New subtask", text: $viewModel.newSubTaskTitle)
                            .textInputAutocapitalization(.sentences)

                        Button {
                            Task {
                                await viewModel.createSubTask(
                                    from: model,
                                    taskId: task.id
                                )
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(!viewModel.canAddSubTask || task.id == nil)
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
            .alert(
                "Subtask",
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.alertMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.alertMessage = nil
                }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .task {
                await viewModel.loadSubTasks(from: model, taskId: task.id)
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
