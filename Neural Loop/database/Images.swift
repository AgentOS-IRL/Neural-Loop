//
//  Images.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import Foundation
import Supabase

// MARK: - Model

struct ImageRecord: Codable, Identifiable, Equatable {
    let id: Int64
    let image_uri: String
    let task_id: Int64?
    let fleeting_note_id: Int64?
    let created_at: Date
}

struct CreateImageRequest: Codable, Equatable {
    let image_uri: String
    let task_id: Int64?
    let fleeting_note_id: Int64?
}

// MARK: - DBManager CRUD

extension DBManager {
    private var imagesTableName: String { "images" }

    // MARK: Fetch

    func fetchImages(forTaskId taskId: Int64) async throws -> [ImageRecord] {
        try await customsupabase
            .from(imagesTableName)
            .select()
            .eq("task_id", value: Int(taskId))
            .order("created_at", ascending: true)
            .execute()
            .value as [ImageRecord]
    }

    func fetchImages(forFleetingNoteId noteId: Int64) async throws -> [ImageRecord] {
        try await customsupabase
            .from(imagesTableName)
            .select()
            .eq("fleeting_note_id", value: Int(noteId))
            .order("created_at", ascending: true)
            .execute()
            .value as [ImageRecord]
    }

    // MARK: Insert

    func insertImages(_ requests: [CreateImageRequest]) async throws -> [ImageRecord] {
        guard !requests.isEmpty else { return [] }

        let inserted: [ImageRecord] = try await customsupabase
            .from(imagesTableName)
            .insert(requests)
            .select()
            .execute()
            .value

        return inserted
    }

    // MARK: Delete

    func deleteImage(id imageId: Int64) async throws {
        try await customsupabase
            .from(imagesTableName)
            .delete()
            .eq("id", value: Int(imageId))
            .execute()
    }

    func deleteImages(ids: [Int64]) async throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            try await deleteImage(id: id)
        }
    }

    // MARK: Replace All (for parent)

    /// Deletes all existing image rows for the given task and inserts the new set.
    func replaceImages(forTaskId taskId: Int64, with requests: [CreateImageRequest]) async throws -> [ImageRecord] {
        // Delete existing rows
        try await customsupabase
            .from(imagesTableName)
            .delete()
            .eq("task_id", value: Int(taskId))
            .execute()

        // Insert new set
        return try await insertImages(requests)
    }

    /// Deletes all existing image rows for the given fleeting note and inserts the new set.
    func replaceImages(forFleetingNoteId noteId: Int64, with requests: [CreateImageRequest]) async throws -> [ImageRecord] {
        // Delete existing rows
        try await customsupabase
            .from(imagesTableName)
            .delete()
            .eq("fleeting_note_id", value: Int(noteId))
            .execute()

        // Insert new set
        return try await insertImages(requests)
    }
}
