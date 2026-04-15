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


extension  UnifiedDataModel {
    
    func getTask(by id: Int64) -> Tasks? {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            return tasks[index]
        }
        return nil
    }
    
    func getSubTasks(taskId: Int64) async -> [SubTasks]{
        do{
            return try await manager.fetchAllSubTasks(task_id: taskId)
        }
        catch {
            print("Error fetching subtasks", error)
            return []
        }
    }
    
    func addSubTask(_ title: String, taskId: Int64) async {
        do{
            let _ = try await manager.addSubTask(title, task_id: taskId)
        }
        catch {
            print("Error adding subtask", error)
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
        do{
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
    
    func deleteTask(task: Tasks) async {
        guard let id = task.id else { return }
        do {
            try await manager.deleteTask(id: id)
            
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks.remove(at: index)
            }
            
        } catch {
            print("Error deleting task", error)
            
        }
    }
    
    func saveTask(_ task: Tasks) async -> Tasks? {
        do {
            let newTask = try await manager.addTask(task)
            tasks.append(newTask)
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
                try await manager.updateTask(modified_task)
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks.remove(at: index)
                    tasks.append(modified_task)
                }
            }
        }
        catch {
            print("Error updating task", error)
        }
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

    var newTaskBucket: DateBucket {
        buildNewTaskBucket(from: tasks)
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


    func updateTaskCompletedStatus(task: Tasks, context: ModelContext) async {
        var modified_task = task
        modified_task.is_completed.toggle()
        do {
            if modified_task.recursion_rule != "" && modified_task.recursion_rule != nil {
                if _shortTermTasksDataBucket.firstIndex(where: { $0.type == .today }) != nil {
                    if modified_task.is_completed {
                        print("Marking recurring task as completed")
                        markRecurringTaskCompleted(taskId: modified_task.id!, date: .now, context: context)
                    } else {
                        try deleteCompletion(taskId: modified_task.id!, on: .now, context: context)
                    }
                }
            } else {
                await updateTask(task: task, modified_task: modified_task)
            }
        } catch {
            print("Error toggling completed status of task", error)
        }

    }
    
}
