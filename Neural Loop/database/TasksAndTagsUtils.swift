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
    /// Creates the tag if it does not exist. If it already exists, returns the existing tag.
    /// - Parameter name: tag name.
    /// - Returns: The existing or newly created tag row.
    func getOrCreateTag(named name: String) async throws -> Tags {
        return try await customsupabase
            .rpc("nl_get_or_create_tag", params: ["p_name": name])
            .execute()
            .value
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

    nonisolated struct FetchTasksForTagParams: Codable, Sendable {
        let p_tag_id: Int64
    }

    /// Finds all tasks linked to one tag, ordered by most recently updated.
    /// - Parameter tagIdValue: tag ID.
    /// - Returns: A list of task rows.
    func fetchTasks(forTag tagIdValue: Int64) async throws -> [Tasks] {
        return try await customsupabase
            .rpc("nl_get_tasks_for_tag", params: FetchTasksForTagParams(p_tag_id: tagIdValue))
            .execute()
            .value
    }

    nonisolated struct SetTaskTagsParams: Codable, Sendable {
        let p_task_id: Int64
        let p_tag_ids: [Int64]
    }

    /// Replaces all tags for a task with the provided tag list in one operation.
    /// - Parameters:
    ///   - taskId: task ID.
    ///   - tagIds: final list of tag IDs for the task.
    /// - Returns: A list of the task’s final tags.
    func setTaskTags(taskId: Int64, tagIds: [Int64]) async throws -> [Tags] {
        return try await customsupabase
            .rpc("nl_set_task_tags", params: SetTaskTagsParams(
                p_task_id: taskId,
                p_tag_ids: tagIds
            ))
            .execute()
            .value
    }
}
