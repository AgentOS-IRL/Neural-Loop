//
//  TasksAndTagsUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//
import Foundation
import SQLite

extension DBManager {

    // MARK: - Tables

    private var tagsTable: Table { Table("Tags") }
    private var taskTagsTable: Table { Table("TaskTags") }
    private var tasksTable: Table { Table("Tasks") }

    // MARK: - Tag Columns

    private var tagId: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    private var tagName: SQLite.Expression<String> { SQLite.Expression<String>("name") }

    // MARK: - TaskTag Columns

    private var taskId: SQLite.Expression<Int64> { SQLite.Expression<Int64>("task_id") }
    private var linkTagId: SQLite.Expression<Int64> { SQLite.Expression<Int64>("tag_id") }

    // MARK: - Task Columns (for joins)

    private var id: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    private var taskTitle: SQLite.Expression<String> { SQLite.Expression<String>("title") }
    private var taskDescription: SQLite.Expression<String?> { SQLite.Expression<String?>("description") }
    private var taskPriority: SQLite.Expression<Int> { SQLite.Expression<Int>("priority") }
    private var taskGoalId: SQLite.Expression<Int64?> { SQLite.Expression<Int64?>("goal_id") }
    private var taskLifeAreaId: SQLite.Expression<Int64?> { SQLite.Expression<Int64?>("lifearea_id") }
    private var taskTarget: SQLite.Expression<Int64?> { SQLite.Expression<Int64?>("target") }
    private var taskLabel: SQLite.Expression<String?> { SQLite.Expression<String?>("label") }
    private var taskIsCompleted: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_completed") }
    private var taskIsDeadline: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_deadline") }
    private var taskCompletedAt: SQLite.Expression<String?> { SQLite.Expression<String?>("completed_at") }
    private var taskRecursionRule: SQLite.Expression<String?> { SQLite.Expression<String?>("recursion_rule") }
    private var taskStartDate: SQLite.Expression<String?> { SQLite.Expression<String?>("start_date") }
    private var taskDuration: SQLite.Expression<Double?> { SQLite.Expression<Double?>("duration") }
    private var taskCreatedAt: SQLite.Expression<String> { SQLite.Expression<String>("created_at") }
    private var taskUpdatedAt: SQLite.Expression<String> { SQLite.Expression<String>("updated_at") }

    // MARK: - Tags CRUD

    func addTag(_ tag: Tags) throws {
        let insert = tagsTable.insert(
            tagName <- tag.name
        )
        _ = try DBManager.sqliteDB!.run(insert)
    }

    /// Insert tag if it doesn't exist, otherwise return existing one
    func getOrCreateTag(named name: String) throws -> Tags {
        if let existing = try DBManager.sqliteDB!.pluck(tagsTable.filter(tagName == name)) {
            return Tags(
                id: existing[tagId],
                name: existing[tagName]
            )
        }

        let rowId = try DBManager.sqliteDB!.run(
            tagsTable.insert(tagName <- name)
        )

        return Tags(id: rowId, name: name)
    }

    func fetchAllTags() throws -> [Tags] {
        try DBManager.sqliteDB!.prepare(tagsTable).map { row in
            Tags(
                id: row[tagId],
                name: row[tagName]
            )
        }
    }

    func deleteTag(id: Int64) throws {
        let query = tagsTable.filter(tagId == id)
        try DBManager.sqliteDB!.run(query.delete())
    }

    // MARK: - Task ↔ Tag Linking

    func addTag(_ tagIdValue: Int64, toTask taskIdValue: Int64) throws {
        let insert = taskTagsTable.insert(
            taskId <- taskIdValue,
            linkTagId <- tagIdValue
        )
        _ = try DBManager.sqliteDB!.run(insert)
    }

    func removeTag(_ tagIdValue: Int64, fromTask taskIdValue: Int64) throws {
        let query = taskTagsTable
            .filter(taskId == taskIdValue && linkTagId == tagIdValue)
        try DBManager.sqliteDB!.run(query.delete())
    }

    func fetchTags(forTask taskIdValue: Int64) throws -> [Tags] {
        let join = tagsTable
            .join(taskTagsTable, on: tagId == linkTagId)
            .filter(taskId == taskIdValue)

        return try DBManager.sqliteDB!.prepare(join).map { row in
            Tags(
                id: row[tagId],
                name: row[tagName]
            )
        }
    }

    func fetchTasks(forTag tagIdValue: Int64) throws -> [Tasks] {
        let join = tasksTable
            .join(taskTagsTable, on: id == taskId)
            .filter(linkTagId == tagIdValue)

        return try DBManager.sqliteDB!.prepare(join).map { row in
            Tasks(
                id: row[id],
                title: row[taskTitle],
                description: row[taskDescription],
                priority: row[taskPriority],
                goal_id: row[taskGoalId],
                lifearea_id: row[taskLifeAreaId],
                target: row[taskTarget],
                label: row[taskLabel],
                is_completed: row[taskIsCompleted],
                is_deadline: row[taskIsDeadline],
                completed_at: row[taskCompletedAt].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                recursion_rule: row[taskRecursionRule],
                start_date: row[taskStartDate].flatMap {
                    ISO8601DateFormatter().date(from: $0)
                },
                duration: row[taskDuration],
                created_at: Date(),
                updated_at: Date()
            )
        }
    }
}
