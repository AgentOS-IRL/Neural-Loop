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
    
    func saveTask(_ task: Tasks) async {
        do {
            let newTask = try await manager.addTask(task)
            tasks.append(newTask)
        }
        catch {
            print("Error saving task", error)
        }
    }
    
    func updateTask(task: Tasks, modified_task: Tasks) async {
        do {
            if task != modified_task {
                try await manager.updateTask(modified_task)
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index] = modified_task
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
    
    func getTodayTasksDateBucket() -> DateBucket {
        if _shortTermTasksDataBucket.isEmpty { reloadShortTermTasksDateBucket() }
        
        return _shortTermTasksDataBucket.first(where: { $0.type == .today })!
        
    }
    
    func getInboxTasksDateBucket() -> DateBucket {
        if _shortTermTasksDataBucket.isEmpty { reloadShortTermTasksDateBucket() }
        
        return _shortTermTasksDataBucket.first(where: { $0.type == .inbox })!
    }
    
    func getCompletedTasksDateBucket() -> DateBucket {
        if _shortTermTasksDataBucket.isEmpty { reloadShortTermTasksDateBucket() }
        
        return _shortTermTasksDataBucket.first(where: { $0.type == .completed})!
    }
    
    func getUpcomingTasksDateBucket() -> [DateBucket] {
        if _shortTermTasksDataBucket.isEmpty { reloadShortTermTasksDateBucket() }
        
        return _shortTermTasksDataBucket.filter({ $0.type == .upcoming})
    }
    
    
    private func reloadShortTermTasksDateBucket() -> Void {
        
        
        let todayStart = calendar.startOfDay(.now)
        let todayEnd = calendar.endOfDay(.now)
        var _dateBuckets = buildShortRangeDateBuckets()
        
        var today_bucket = DateBucket(
            title: AnyView( Text("Today")
                    .font(.title3.weight(.semibold))
                .foregroundColor(.primary))
                ,
            start: todayStart,
            end: todayEnd,
            type: .today
        )

        var inbox_bucket = DateBucket(title: AnyView( Text("Inbox")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)), start: .distantPast, end: .now, type: .inbox)

        var overdue_bucket = DateBucket(title: AnyView( Text("Overdue")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)), start: .distantPast, end: .now, type: .overdue)
        var completed_bucket = DateBucket(title: AnyView( Text("Completed")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)), start: .distantPast, end: .distantFuture, type: .completed)

        for task in tasks {
            print(task.title)
            if task.start_date == nil {
                inbox_bucket.ids.append(task.id!)
            }
            else if task.is_completed {
                completed_bucket.ids.append(task.id!)
            }
            else if (task.recursion_rule == "" || task.recursion_rule == nil) && task.start_date != nil {
                if task.start_date! < todayStart {
                    overdue_bucket.ids.append(task.id!)
                }
                else if task.start_date! < todayEnd {
                    today_bucket.ids.append(task.id!)
                }
                else{
                    _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
                }

            }
            else {
                _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
            }
        }

        _shortTermTasksDataBucket = [inbox_bucket, today_bucket, overdue_bucket, completed_bucket] + _dateBuckets
        
        
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
