//
//  Tasks.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import Supabase

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
            print("Start fetching tasks")
            let builder = customsupabase
                .from(self.tasksTableName)
                .select()
            
            return try await builder.execute().value as [Tasks]
        
    }
    
    func fetchAllTasksByDate(date: Date) async throws -> [Tasks] {
        let calendar = Calendar.current

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
        try await customsupabase
            .from(self.tasksTableName)
            .select()
            .eq("lifearea_id", value: Int(lifeAreaId))
            .execute()
            .value as [Tasks]
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
    func updateTask(_ task: Tasks) async throws {
        guard let taskId = task.id else { return }
        
        var modified_task = task
        modified_task.updated_at = Date()
        _ = try await customsupabase
            .from(self.tasksTableName)
            .update(modified_task)
            .eq("id", value: Int(taskId))
            .select()
            .execute()
    }

    func markTaskCompleted(taskId: Int64) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        _ = try await customsupabase
            .from(tasksTableName)
            .update([
                "is_completed": "true",
                "completed_at": now,
                "updated_at": now
            ])
            .eq("id", value: Int(taskId))
            .execute()
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
