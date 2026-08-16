//
//  FleetingNotes.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import Foundation
import Supabase

struct FleetingNote: Codable, Identifiable, Equatable {
    let id: Int64
    let created_at: Date
    let note: String
    let watch_action_id: UUID?
    let task_id: Int64?

    init(
        id: Int64,
        created_at: Date,
        note: String,
        watch_action_id: UUID? = nil,
        task_id: Int64? = nil
    ) {
        self.id = id
        self.created_at = created_at
        self.note = note
        self.watch_action_id = watch_action_id
        self.task_id = task_id
    }
}

struct CreateFleetingNoteRequest: Codable, Equatable {
    let note: String
    let watch_action_id: UUID?
    let task_id: Int64?

    init(note: String, watch_action_id: UUID? = nil, task_id: Int64? = nil) {
        self.note = note
        self.watch_action_id = watch_action_id
        self.task_id = task_id
    }
}

struct UpdateFleetingNoteRequest: Encodable, Equatable {
    let note: String
    let task_id: Int64?

    init(note: String, task_id: Int64? = nil) {
        self.note = note
        self.task_id = task_id
    }

    private enum CodingKeys: String, CodingKey {
        case note
        case task_id
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(note, forKey: .note)
        // Unlike create requests, updates must send JSON null to unlink a note.
        try container.encode(task_id, forKey: .task_id)
    }
}

struct TaskNoteCountRow: Codable, Equatable {
    let task_id: Int64
    let note_count: Int64
}

enum FleetingNotesError: LocalizedError, Equatable {
    case insertReturnedNoRows
    case updateReturnedNoRows

    var errorDescription: String? {
        switch self {
        case .insertReturnedNoRows:
            return "Fleeting note could not be saved."
        case .updateReturnedNoRows:
            return "Fleeting note could not be updated."
        }
    }
}

extension FleetingNote {
    static let tableName = "fleeting notes"
    static let selectedColumns = "id, created_at, note, watch_action_id, task_id"

    static func sortedNewestFirst(_ notes: [FleetingNote]) -> [FleetingNote] {
        notes.sorted {
            if $0.created_at == $1.created_at {
                return $0.id > $1.id
            }

            return $0.created_at > $1.created_at
        }
    }
}

extension DBManager {
    func fetchFleetingNotes() async throws -> [FleetingNote] {
        let rows: [FleetingNote] = try await customsupabase
            .from(FleetingNote.tableName)
            .select(FleetingNote.selectedColumns)
            .order("created_at", ascending: false)
            .execute()
            .value

        return FleetingNote.sortedNewestFirst(rows)
    }

    func fetchFleetingNotes(taskId: Int64) async throws -> [FleetingNote] {
        let rows: [FleetingNote] = try await customsupabase
            .from(FleetingNote.tableName)
            .select(FleetingNote.selectedColumns)
            .eq("task_id", value: Int(taskId))
            .order("created_at", ascending: false)
            .execute()
            .value

        return FleetingNote.sortedNewestFirst(rows)
    }

    func fetchTaskNoteCounts() async throws -> [TaskNoteCountRow] {
        try await customsupabase
            .rpc("nl_get_task_note_counts")
            .execute()
            .value
    }

    func createFleetingNote(_ request: CreateFleetingNoteRequest) async throws -> FleetingNote {
        let inserted: [FleetingNote] = try await customsupabase
            .from(FleetingNote.tableName)
            .insert(request)
            .select(FleetingNote.selectedColumns)
            .execute()
            .value

        guard let note = inserted.first else {
            throw FleetingNotesError.insertReturnedNoRows
        }

        return note
    }

    /// Creates a note idempotently for a watch action. The database continues
    /// to generate the note's ordinary numeric ID; the nullable action UUID is
    /// used only as the conflict target for exactly-once watch retries.
    func createFleetingNoteFromWatch(text: String, actionID: UUID) async throws -> FleetingNote {
        let request = CreateFleetingNoteRequest(
            note: text,
            watch_action_id: actionID
        )

        return try await customsupabase
            .from(FleetingNote.tableName)
            .upsert(request, onConflict: "watch_action_id")
            .select(FleetingNote.selectedColumns)
            .single()
            .execute()
            .value
    }

    func updateFleetingNote(id: Int64, request: UpdateFleetingNoteRequest) async throws -> FleetingNote {
        let updated: [FleetingNote] = try await customsupabase
            .from(FleetingNote.tableName)
            .update(request)
            .eq("id", value: Int(id))
            .select(FleetingNote.selectedColumns)
            .execute()
            .value

        guard let note = updated.first else {
            throw FleetingNotesError.updateReturnedNoRows
        }

        return note
    }

    func deleteFleetingNote(id: Int64) async throws {
        try await customsupabase
            .from(FleetingNote.tableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }
}
