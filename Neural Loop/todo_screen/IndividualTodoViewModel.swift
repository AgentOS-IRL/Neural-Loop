//
//  IndividualTodoViewModel.swift
//  Neural Loop
//
//  Created by Codex on 20/04/2026.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class IndividualTodoViewModel: ObservableObject {
    @Published var subTasks: [SubTasks] = []
    @Published var newSubTaskTitle: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published var alertMessage: String?

    var trimmedNewSubTaskTitle: String {
        newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAddSubTask: Bool {
        !trimmedNewSubTaskTitle.isEmpty
    }

    func loadSubTasks(from model: TodoSubtaskServicing, taskId: Int64?) async {
        guard let taskId else {
            subTasks = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        subTasks = await model.getSubTasks(taskId: taskId)
    }

    func createSubTask(from model: TodoSubtaskServicing, taskId: Int64?) async {
        guard let taskId else {
            alertMessage = "This task cannot accept subtasks yet."
            return
        }

        let trimmedTitle = trimmedNewSubTaskTitle
        guard !trimmedTitle.isEmpty else { return }

        guard let _ = await model.addSubTask(trimmedTitle, taskId: taskId) else {
            alertMessage = "Unable to add subtask."
            return
        }

        alertMessage = nil
        newSubTaskTitle = ""
        await loadSubTasks(from: model, taskId: taskId)
    }

    func deleteSubTask(
        at offsets: IndexSet,
        from model: TodoSubtaskServicing,
        taskId: Int64?
    ) async {
        guard let taskId else { return }

        for index in offsets {
            guard subTasks.indices.contains(index) else { continue }
            let subtask = subTasks[index]
            await model.deleteSubTask(subtask_id: subtask.id)
        }

        await loadSubTasks(from: model, taskId: taskId)
    }

    func toggleSubTask(
        _ subTask: SubTasks,
        from model: TodoSubtaskServicing,
        taskId: Int64?
    ) async {
        guard let taskId else { return }

        await model.setSubTaskIsCompleted(
            subtask_id: subTask.id,
            is_completed: !subTask.is_completed
        )

        await loadSubTasks(from: model, taskId: taskId)
    }
}
