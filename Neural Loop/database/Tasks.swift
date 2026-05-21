//
//  Tasks.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import Supabase

struct SubTasks: Codable, Identifiable{
    static let databasePrimaryKey = ["id"]
    
    var id: UUID = UUID()
    var task_id: Int64?
    var title: String
    var is_completed: Bool
}

extension SubTasks: Equatable {}

struct TaskDetailBundle: Codable {
    let task: Tasks
    let subtasks: [SubTasks]
    let tags: [Tags]
}

struct Tasks: Codable, Identifiable{
    static let databasePrimaryKey = ["id"]

    // MARK: - Properties
    var id: Int64?

    var title: String
    var description: String?

    /// 0 = lowest, 3 = highest (enforced by CHECK in DB)
    var priority: Int

    /// Nullable relationships
    var goal_id: Int64?
    var lifearea_id: Int64?


    /// 0 = false, 1 = true
    var is_completed: Bool
    var is_deadline: Bool

    /// ISO-8601 datetime string
    var completed_at: Date?

    /// Optional recurrence rule (RRULE / custom string)
    var recursion_rule: String?

    /// Start date for recurring tasks (stored as ISO-8601 TEXT in SQLite)
    var start_date: Date?

    /// Optional duration in seconds
    var duration: Double?

    /// Auto-filled by DB
    var created_at: Date?
    var updated_at: Date?
}

extension Tasks: Equatable {
    static func == (lhs: Tasks, rhs: Tasks) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description &&
        lhs.priority == rhs.priority &&
        lhs.goal_id == rhs.goal_id &&
        lhs.lifearea_id == rhs.lifearea_id &&
        lhs.is_completed == rhs.is_completed &&
        lhs.is_deadline == rhs.is_deadline &&
        lhs.completed_at == rhs.completed_at &&
        lhs.recursion_rule == rhs.recursion_rule &&
        lhs.start_date == rhs.start_date &&
        lhs.duration == rhs.duration
    }
}

extension DBManager {
    private var tasksTableName: String { "tasks" }
    private var subTasksTableName: String { "subtasks" }
    
    func addSubTask(_ subtask_title: String, task_id: Int64) async throws -> SubTasks {
        let subtask = SubTasks(
            id: UUID(),
            task_id: Int64(task_id), title: subtask_title,
            is_completed: false
        )
        let inserted: [SubTasks] = try await customsupabase
            .from(self.subTasksTableName)
            .insert(subtask)
            .select()
            .execute()
            .value
        return inserted.first ?? subtask
    }
    
    func fetchAllSubTasks(task_id: Int64) async throws -> [SubTasks] {
        let builder = customsupabase
            .from(self.subTasksTableName)
            .select()
            .eq("task_id", value: Int(task_id))

        return try await builder.execute().value as [SubTasks]
    }
    
    func setSubTaskIsCompleted(subtask_id: UUID, is_completed: Bool) async throws -> Void {
        
        let builder = try customsupabase
            .from(self.subTasksTableName)
            .update(["is_completed": is_completed])
            .eq("id", value: subtask_id)
        
        try await builder.execute()
        
    }
    
    func deleteSubTask(subtask_id: UUID) async throws -> Void {
        
        let builder = customsupabase
            .from(self.subTasksTableName)
            .delete()
            .eq("id", value: subtask_id)
        
        try await builder.execute()
    }
    

    // MARK: - Create
    func addTask(_ task: Tasks) async throws -> Tasks {
        let inserted: [Tasks] = try await customsupabase
            .from(self.tasksTableName)
            .insert(task)
            .select()
            .execute()
            .value
        return inserted.first ?? task
    }

    // MARK: - Read
    func fetchAllTasks(get_habits: Bool = false) async throws -> [Tasks] {
            
            let builder = customsupabase
                .from(self.tasksTableName)
                .select()
            
            return try await builder.execute().value as [Tasks]
        
    }
    
    func fetchAllTasksByDate(date: Date) async throws -> [Tasks] {
        let calendar = Calendar.neuralLoopDisplay

        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: startOfDay
        )!

        return try await customsupabase
            .from(self.tasksTableName)
            .select()
            .gte("start_date", value: startOfDay)
            .lt("start_date", value: endOfDay)
            .execute()
            .value as [Tasks]
    }

    func fetchTask(by idValue: Int64) async throws -> Tasks? {
        let rows: [Tasks] = try await customsupabase
            .from(self.tasksTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchTasks(forGoal goalIdValue: Int64) async throws -> [Tasks] {
        try await customsupabase
            .from(self.tasksTableName)
            .select()
            .eq("goal_id", value: Int(goalIdValue))
            .execute()
            .value as [Tasks]
    }

    func fetchTasksforLifeArea( lifeAreaId: Int64) async throws -> [Tasks] {
        let tasks = try await customsupabase
            .from(self.tasksTableName)
            .select()
            .eq("lifearea_id", value: Int(lifeAreaId))
            .execute()
            .value as [Tasks]
        return tasks
        
    }
    
    func fetchTasksforGoal( goalId: Int64) async throws -> [Tasks] {
        try await customsupabase
            .from(self.tasksTableName)
            .select()
            .eq("goal_id", value: Int(goalId))
            .execute()
            .value as [Tasks]
    }

    func fetchIncompleteTasks() async throws -> [Tasks] {
        try await customsupabase
            .from(self.tasksTableName)
            .select()
            .eq("is_completed", value: false)
            .execute()
            .value as [Tasks]
    }

    // MARK: - Update
    private struct TaskUpdatePayload: Codable {
        let title: String
        let description: String?
        let priority: Int
        let goal_id: Int64?
        let lifearea_id: Int64?
        let is_completed: Bool
        let is_deadline: Bool
        let completed_at: Date?
        let recursion_rule: String?
        let start_date: Date?
        let duration: Double?
        let updated_at: Date
    }

    func updateTask(_ task: Tasks) async throws -> Tasks {
        guard let taskId = task.id else { return task }

        let payload = TaskUpdatePayload(
            title: task.title,
            description: task.description,
            priority: task.priority,
            goal_id: task.goal_id,
            lifearea_id: task.lifearea_id,
            is_completed: task.is_completed,
            is_deadline: task.is_deadline,
            completed_at: task.completed_at,
            recursion_rule: task.recursion_rule,
            start_date: task.start_date,
            duration: task.duration,
            updated_at: Date()
        )

        let updatedRows: [Tasks] = try await customsupabase
            .from(self.tasksTableName)
            .update(payload)
            .eq("id", value: Int(taskId))
            .select()
            .execute()
            .value

        if let updated = updatedRows.first {
            return updated
        }
        return task
    }

    nonisolated struct FetchTaskDetailParams: Codable, Sendable {
        let p_task_id: Int64
    }

    /// Fetches all data needed for one task detail screen.
    /// - Parameter taskId: task ID.
    /// - Returns: A JSON object with the task, subtasks, and tags.
    func fetchTaskDetail(taskId: Int64) async throws -> TaskDetailBundle {
        return try await customsupabase
            .rpc("nl_get_task_detail", params: FetchTaskDetailParams(p_task_id: taskId))
            .execute()
            .value
    }

    nonisolated struct MarkTaskCompletedParams: Codable, Sendable {
        let p_task_id: Int64
        let p_completed: Bool
    }

    /// Updates task completion state, sets or clears `completed_at`, updates `updated_at`, and returns the saved task row.
    /// - Parameters:
    ///   - taskId: task ID.
    ///   - completed: `true` to mark completed, `false` to mark incomplete. Default `true`.
    /// - Returns: The updated task row.
    func markTaskCompleted(taskId: Int64, completed: Bool = true) async throws -> Tasks {
        return try await customsupabase
            .rpc("nl_mark_task_completed", params: MarkTaskCompletedParams(
                p_task_id: taskId,
                p_completed: completed
            ))
            .execute()
            .value
    }

    // MARK: - Delete
    func deleteTask(id taskId: Int64) async throws {
        _ = try await customsupabase
            .from(self.tasksTableName)
            .delete()
            .eq("id", value: Int(taskId))
            .execute()
    }
}
