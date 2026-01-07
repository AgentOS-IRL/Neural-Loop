//
//  Tasks.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import SQLite

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

    /// Optional target reference (default 0)
    var target: Int64? = 0

    /// Optional label
    var label: String?

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

    /// Auto-filled by DB (datetime('now'))
    var created_at: Date = Date()
    var updated_at: Date = Date()
}

extension DBManager {

    // MARK: - Table & Columns

    private var tasksTable: Table {
        Table("Tasks")
    }

    private var id: SQLite.Expression<Int64> { Expression<Int64>("id") }
    private var title: SQLite.Expression<String> { Expression<String>("title") }
    private var description: SQLite.Expression<String?> { Expression<String?>("description") }
    private var priority: SQLite.Expression<Int> { Expression<Int>("priority") }

    private var goalId: SQLite.Expression<Int64?> { Expression<Int64?>("goal_id") }
    private var lifeAreaId: SQLite.Expression<Int64?> { Expression<Int64?>("lifearea_id") }

    private var targetColumn: SQLite.Expression<Int64?> { Expression<Int64?>("target") }
    private var labelColumn: SQLite.Expression<String?> { Expression<String?>("label") }

    private var isCompleted: SQLite.Expression<Bool> { Expression<Bool>("is_completed") }
    private var isDeadline: SQLite.Expression<Bool> { Expression<Bool>("is_deadline") }
    private var completedAt: SQLite.Expression<String?> { Expression<String?>("completed_at") }
    private var recursionRule: SQLite.Expression<String?> { Expression<String?>("recursion_rule") }
    private var startDate: SQLite.Expression<String?> { Expression<String?>("start_date") }
    private var durationColumn: SQLite.Expression<Double?> { Expression<Double?>("duration") }

    private var createdAt: SQLite.Expression<String> { Expression<String>("created_at") }
    private var updatedAt: SQLite.Expression<String> { Expression<String>("updated_at") }

    // MARK: - Create

    func addTask(_ task: Tasks) throws -> Tasks {
        print("Add Task")
        let insert = tasksTable.insert(
            title <- task.title,
            description <- task.description,
            priority <- task.priority,
            goalId <- task.goal_id,
            lifeAreaId <- task.lifearea_id,
            targetColumn <- task.target,
            labelColumn <- task.label,
            isCompleted <- task.is_completed,
            isDeadline <- task.is_deadline,
            completedAt <- task.completed_at?.ISO8601Format(),
            recursionRule <- task.recursion_rule,
            startDate <- task.start_date?.ISO8601Format(),
            durationColumn <- task.duration,
        )

        let rowId = try DBManager.sqliteDB!.run(insert)

        var newTask = task
        newTask.id = rowId
        print("Done adding Task")
        return newTask
    }

    // MARK: - Read

    func fetchAllTasks(get_habits: Bool = false) throws -> [Tasks] {
        let query = get_habits ? tasksTable.filter(targetColumn>0)  : tasksTable.filter(targetColumn==0 || targetColumn==nil)
        
        return try DBManager.sqliteDB!.prepare(query).map { row in
            Tasks(
                id: row[id],
                title: row[title],
                description: row[description],
                priority: row[priority],
                goal_id: row[goalId],
                lifearea_id: row[lifeAreaId],
                target: row[targetColumn],
                label: row[labelColumn],
                is_completed: row[isCompleted],
                is_deadline: row[isDeadline],
                completed_at: row[completedAt].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                recursion_rule: row[recursionRule],
                start_date: row[startDate].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                duration: row[durationColumn],
                created_at: Date(),
                updated_at: Date()
            )
        }
    }

    func fetchTask(by idValue: Int64) throws -> Tasks? {
        let query = tasksTable.filter(id == idValue)
        return try DBManager.sqliteDB!.pluck(query).map { row in
            Tasks(
                id: row[id],
                title: row[title],
                description: row[description],
                priority: row[priority],
                goal_id: row[goalId],
                lifearea_id: row[lifeAreaId],
                target: row[targetColumn],
                label: row[labelColumn],
                is_completed: row[isCompleted],
                is_deadline: row[isDeadline],
                completed_at: row[completedAt].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                recursion_rule: row[recursionRule],
                start_date: row[startDate].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                duration: row[durationColumn],
                created_at: Date(),
                updated_at: Date()
            )
        }
    }

    func fetchTasks(forGoal goalIdValue: Int64) throws -> [Tasks] {
        let query = tasksTable.filter(goalId == goalIdValue)
        return try DBManager.sqliteDB!.prepare(query).map { row in
            Tasks(
                id: row[id],
                title: row[title],
                description: row[description],
                priority: row[priority],
                goal_id: row[goalId],
                lifearea_id: row[lifeAreaId],
                target: row[targetColumn],
                label: row[labelColumn],
                is_completed: row[isCompleted],
                is_deadline: row[isDeadline],
                completed_at: row[completedAt].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                recursion_rule: row[recursionRule],
                start_date: row[startDate].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                duration: row[durationColumn],
                created_at: Date(),
                updated_at: Date()
            )
        }
    }

    func fetchTasks(forLifeArea lifeAreaIdValue: Int64) throws -> [Tasks] {
        let query = tasksTable.filter(lifeAreaId == lifeAreaIdValue)
        return try DBManager.sqliteDB!.prepare(query).map { row in
            Tasks(
                id: row[id],
                title: row[title],
                description: row[description],
                priority: row[priority],
                goal_id: row[goalId],
                lifearea_id: row[lifeAreaId],
                target: row[targetColumn],
                label: row[labelColumn],
                is_completed: row[isCompleted],
                is_deadline: row[isDeadline],
                completed_at: row[completedAt].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                recursion_rule: row[recursionRule],
                start_date: row[startDate].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                duration: row[durationColumn],
                created_at: Date(),
                updated_at: Date()
            )
        }
    }

    func fetchIncompleteTasks() throws -> [Tasks] {
        let query = tasksTable.filter(isCompleted == false)
        return try DBManager.sqliteDB!.prepare(query).map { row in
            Tasks(
                id: row[id],
                title: row[title],
                description: row[description],
                priority: row[priority],
                goal_id: row[goalId],
                lifearea_id: row[lifeAreaId],
                target: row[targetColumn],
                label: row[labelColumn],
                is_completed: row[isCompleted],
                is_deadline: row[isDeadline],
                completed_at: row[completedAt].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                recursion_rule: row[recursionRule],
                start_date: row[startDate].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                duration: row[durationColumn],
                created_at: Date(),
                updated_at: Date()
            )
        }
    }

    // MARK: - Update

    func updateTask(_ task: Tasks) throws {
        guard let taskId = task.id else { return }

        let query = tasksTable.filter(id == taskId)
        try DBManager.sqliteDB!.run(
            query.update(
                title <- task.title,
                description <- task.description,
                priority <- task.priority,
                goalId <- task.goal_id,
                lifeAreaId <- task.lifearea_id,
                targetColumn <- task.target,
                labelColumn <- task.label,
                isCompleted <- task.is_completed,
                isDeadline <- task.is_deadline,
                completedAt <- task.completed_at?.ISO8601Format(),
                recursionRule <- task.recursion_rule,
                startDate <- task.start_date?.ISO8601Format(),
                durationColumn <- task.duration,
                updatedAt <- Date().ISO8601Format()
            )
        )
    }

    func markTaskCompleted(taskId: Int64) throws {
        let query = tasksTable.filter(id == taskId)
        try DBManager.sqliteDB!.run(
            query.update(
                isCompleted <- true,
                completedAt <- Date().ISO8601Format(),
                updatedAt <- Date().ISO8601Format()
            )
        )
    }

    // MARK: - Delete

    func deleteTask(id taskId: Int64) throws {
        let query = tasksTable.filter(id == taskId)
        try DBManager.sqliteDB!.run(query.delete())
    }
}
