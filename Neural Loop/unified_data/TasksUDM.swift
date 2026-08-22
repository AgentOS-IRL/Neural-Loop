//
//  TasksUDM.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 16/01/2026.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
protocol TodoSubtaskServicing {
    func getTaskDetailBundle(taskId: Int64) async -> TaskDetailBundle?
    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks?
    func setSubTaskIsCompleted(subtask_id: UUID, is_completed: Bool) async
    func deleteSubTask(subtask_id: UUID) async
}

extension  UnifiedDataModel {
    
    func getTask(by id: Int64) -> Tasks? {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            return tasks[index]
        }
        return nil
    }
    
    func getTaskDetailBundle(taskId: Int64) async -> TaskDetailBundle? {
        do {
            return try await manager.fetchTaskDetail(taskId: taskId)
        }
        catch {
            print("Error fetching task detail", error)
            return nil
        }
    }
    
    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks? {
        do {
            return try await manager.addSubTask(title, task_id: taskId)
        }
        catch {
            print("Error adding subtask", error)
            return nil
        }
    }
    
    func setSubTaskIsCompleted(subtask_id: UUID, is_completed: Bool) async {
        do {
            try await manager.setSubTaskIsCompleted(subtask_id: subtask_id, is_completed: is_completed)
        }
        catch {
            print("Error updating subtask", error)
        }
    }
    
    func deleteSubTask(subtask_id: UUID) async {
        do {
            try await manager.deleteSubTask(subtask_id: subtask_id)
        }
        catch {
            print("Error deleting subtask", error)
        }
    }
    
    func getTasks(lifeAreaId: Int64) -> [Tasks] {
        return tasks.filter { $0.lifearea_id == lifeAreaId }
    }
    
    func getTasks(goalId: Int64) -> [Tasks] {
        return tasks.filter { $0.goal_id == goalId }
    }
    
    
    func getTasks(date:Date) async -> [Tasks]{
        do {
            return try await manager.fetchAllTasksByDate(date: date)
        }
        catch {
            print("Error fetching tasks", error)
            return []
        }
        
    }
    
    func deleteTask(task: Tasks, context: ModelContext) async {
        guard let id = task.id else { return }
        do {
            try await manager.deleteTask(id: id)
            
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks.remove(at: index)
            }
            taskNoteCounts.removeValue(forKey: id)

            await notificationScheduler.clearTaskNotifications(taskId: id)

            do {
                try deleteRecurringTaskCompletions(taskId: id, context: context)
            } catch {
                print("Error deleting local recurring task completions", error)
            }
            
        } catch {
            print("Error deleting task", error)
            
        }
    }
    
    func saveTask(_ task: Tasks) async -> Tasks? {
        do {
            let newTask = try await manager.addTask(task)
            tasks.append(newTask)
            await refreshTaskNotifications(for: newTask)
            return newTask
        }
        catch {
            print("Error saving task", error)
            return nil
        }
    }
    
    func updateTask(task: Tasks, modified_task: Tasks) async {
        do {
            if task != modified_task {
                let savedTask = try await manager.updateTask(modified_task)
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks.remove(at: index)
                    tasks.append(savedTask)
                }
                await refreshTaskNotifications(for: savedTask)
            }
        }
        catch {
            print("Error updating task", error)
        }
    }

    func setTaskCompleted(taskId: Int64, completed: Bool) async -> Tasks? {
        do {
            let savedTask = try await manager.markTaskCompleted(
                taskId: taskId,
                completed: completed
            )

            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index] = savedTask
            } else {
                tasks.append(savedTask)
            }

            await refreshTaskNotifications(for: savedTask)
            return savedTask
        }
        catch {
            print("Error updating task completion", error)
            return nil
        }
    }

    func setTaskCompletedFromWatch(taskId: Int64, completed: Bool) async throws {
        guard let task = tasks.first(where: { $0.id == taskId }) else {
            throw DailyLoopWatchMutationError.taskNotFound
        }
        guard task.recursion_rule?.isEmpty != false else {
            throw DailyLoopWatchMutationError.missingOccurrence
        }

        let savedTask = try await manager.markTaskCompleted(
            taskId: taskId,
            completed: completed
        )

        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index] = savedTask
        } else {
            tasks.append(savedTask)
        }

        await refreshTaskNotifications(for: savedTask)
    }

    func setRecurringTaskCompletedFromWatch(
        taskId: Int64,
        occurrenceStart: Date,
        completed: Bool,
        context: ModelContext
    ) async throws {
        guard let task = tasks.first(where: { $0.id == taskId }) else {
            throw DailyLoopWatchMutationError.taskNotFound
        }
        guard task.recursion_rule?.isEmpty == false else {
            throw DailyLoopWatchMutationError.unexpectedOccurrence
        }

        try setRecurringTaskCompleted(
            taskId: taskId,
            occurrenceStart: occurrenceStart,
            completed: completed,
            context: context
        )
        await notificationScheduler.scheduleTask(task)
    }
    
    func filterTasks(searchText: String) -> [Tasks] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var resolvedShortTermTaskBuckets: [DateBucket] {
        if _shortTermTasksDataBucket.isEmpty {
            reloadShortTermTasksDateBucket()
        }
        return _shortTermTasksDataBucket
    }

    var shortTermTaskBuckets: [DateBucket] {
        resolvedShortTermTaskBuckets
    }

    func shortTermTaskBuckets(from tasks: [Tasks]) -> [DateBucket] {
        rebuildDateBuckets(tasks: tasks)
    }

    var todayTaskBucket: DateBucket {
        resolvedShortTermTaskBuckets.first(where: { $0.type == .today })!
    }

    var inboxTaskBucket: DateBucket {
        resolvedShortTermTaskBuckets.first(where: { $0.type == .inbox })!
    }

    var completedTaskBucket: DateBucket {
        resolvedShortTermTaskBuckets.first(where: { $0.type == .completed })!
    }

    var inProcessTaskBucket: DateBucket {
        buildInProcessTaskBucket(from: tasks)
    }

    var upcomingTaskBuckets: [DateBucket] {
        resolvedShortTermTaskBuckets.filter({ $0.type == .upcoming })
    }

    func getTodayTasksDateBucket() -> DateBucket {
        todayTaskBucket
    }

    func getInboxTasksDateBucket() -> DateBucket {
        inboxTaskBucket
    }

    func getCompletedTasksDateBucket() -> DateBucket {
        completedTaskBucket
    }

    func getUpcomingTasksDateBucket() -> [DateBucket] {
        upcomingTaskBuckets
    }
    
    
    private func reloadShortTermTasksDateBucket() -> Void {
        _shortTermTasksDataBucket = rebuildDateBuckets(tasks: tasks)
    }


    func updateTaskCompletedStatus(
        task: Tasks,
        occurrenceStart: Date? = nil,
        context: ModelContext
    ) async {
        do {
            if let rule = task.recursion_rule, !rule.isEmpty {
                guard
                    let taskId = task.id,
                    let occurrenceStart = occurrenceStart ?? recurringTaskOccurrenceStart(for: task, on: .now)
                else {
                    return
                }

                _ = try toggleRecurringTaskCompleted(
                    taskId: taskId,
                    occurrenceStart: occurrenceStart,
                    context: context
                )
                await notificationScheduler.scheduleTask(task)
            } else {
                guard let taskId = task.id else { return }
                _ = await setTaskCompleted(
                    taskId: taskId,
                    completed: !task.is_completed
                )
            }
        } catch {
            print("Error toggling completed status of task", error)
        }

    }

    private func refreshTaskNotifications(for task: Tasks) async {
        guard let taskId = task.id else { return }

        if task.is_completed, (task.recursion_rule == nil || task.recursion_rule?.isEmpty == true) {
            await notificationScheduler.clearTaskNotifications(taskId: taskId)
            return
        }

        await notificationScheduler.scheduleTask(task)
    }
    
    // MARK: - Task Image Attachments

    func saveImageAttachments(_ attachments: [ImageAttachment], forTaskId taskId: Int64) async {
        guard !attachments.isEmpty else { return }

        let requests = attachments.map {
            CreateImageRequest(image_uri: $0.dataURL, task_id: taskId, fleeting_note_id: nil)
        }

        do {
            _ = try await manager.insertImages(requests)
        } catch {
            print("Error saving task image attachments", error)
        }
    }

    func replaceImageAttachments(_ attachments: [ImageAttachment], forTaskId taskId: Int64) async {
        do {
            let existingRecords = try await manager.fetchImages(forTaskId: taskId)
            let existingRecordIDs = Set(existingRecords.map(\.id))
            let keptRecordIDs = Set(attachments.compactMap(\.existingRecordId))
            let idsToDelete = Array(existingRecordIDs.subtracting(keptRecordIDs))
            let requestsToInsert = attachments
                .filter { $0.existingRecordId == nil }
                .map { CreateImageRequest(image_uri: $0.dataURL, task_id: taskId, fleeting_note_id: nil) }

            if !idsToDelete.isEmpty {
                try await manager.deleteImages(ids: idsToDelete)
            }

            if !requestsToInsert.isEmpty {
                _ = try await manager.insertImages(requestsToInsert)
            }
        } catch {
            print("Error replacing task image attachments", error)
        }
    }

    func fetchImageAttachments(forTaskId taskId: Int64) async -> [ImageAttachment] {
        do {
            let records = try await manager.fetchImages(forTaskId: taskId)
            return records.compactMap { record in
                guard let thumbnailData = record.image_uri.decodedDataURLPayload() else { return nil }
                return ImageAttachment(
                    dataURL: record.image_uri,
                    thumbnailData: thumbnailData,
                    existingRecordId: record.id
                )
            }
        } catch {
            print("Error fetching task image attachments", error)
            return []
        }
    }
}

extension UnifiedDataModel: TodoSubtaskServicing {}
