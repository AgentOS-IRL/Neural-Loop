//
//  TasksAndTagsUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//
import Foundation
import Supabase

extension DBManager {
    // MARK: - Table names
    private var tagsTableName: String { "tags" }
    private var taskTagsTableName: String { "task_tags" }
    private var tasksTableName: String { "tasks" }

    // MARK: - Tags CRUD
    func addTag(_ tag: Tags) async throws {
        _ = try await customsupabase
            .from(self.tagsTableName)
            .insert(tag)
            .execute()
    }

    /// Insert tag if it doesn't exist, otherwise return existing one
    func getOrCreateTag(named name: String) async throws -> Tags {
        let existing: [Tags] = try await customsupabase
            .from(self.tagsTableName)
            .select()
            .eq("name", value: name)
            .limit(1)
            .execute()
            .value
        if let first = existing.first { return first }

        let inserted: [Tags] = try await customsupabase
            .from(self.tagsTableName)
            .insert(["name": name])
            .select()
            .execute()
            .value
        return inserted.first ?? Tags(id: nil, name: name)
    }

    func fetchAllTags() async throws -> [Tags] {
        try await customsupabase
            .from(self.tagsTableName)
            .select()
            .execute()
            .value as [Tags]
    }

    func deleteTag(id: Int64) async throws {
        _ = try await customsupabase
            .from(self.tagsTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    // MARK: - Task ↔ Tag Linking
    func addTag(_ tagIdValue: Int64, toTask taskIdValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.taskTagsTableName)
            .insert(["task_id": taskIdValue, "tag_id": tagIdValue])
            .execute()
    }

    func removeTag(_ tagIdValue: Int64, fromTask taskIdValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.taskTagsTableName)
            .delete()
            .eq("task_id", value: Int(taskIdValue))
            .eq("tag_id", value: Int(tagIdValue))
            .execute()
    }

    func fetchTags(forTask taskIdValue: Int64) async throws -> [Tags] {
        // First fetch task_tags rows for task
        let links: [TaskTags] = try await customsupabase
            .from(self.taskTagsTableName)
            .select()
            .eq("task_id", value: Int(taskIdValue))
            .execute()
            .value
        let ids = links.map { $0.tag_id }
        guard !ids.isEmpty else { return [] }
        let orFilter = ids.map { "id.eq.\($0)" }.joined(separator: ",")
        return try await customsupabase
            .from(self.tagsTableName)
            .select()
            .or(orFilter)
            .execute()
            .value as [Tags]
    }

    func fetchTasks(forTag tagIdValue: Int64) async throws -> [Tasks] {
        let links: [TaskTags] = try await customsupabase
            .from(self.taskTagsTableName)
            .select()
            .eq("tag_id", value: Int(tagIdValue))
            .execute()
            .value
        let ids = links.map { $0.task_id }
        guard !ids.isEmpty else { return [] }
        let orFilter = ids.map { "id.eq.\($0)" }.joined(separator: ",")
        return try await customsupabase
            .from(self.tasksTableName)
            .select()
            .or(orFilter)
            .execute()
            .value as [Tasks]
    }
}
