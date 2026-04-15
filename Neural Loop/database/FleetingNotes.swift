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
}

struct CreateFleetingNoteRequest: Codable, Equatable {
    let note: String
}

enum FleetingNotesError: LocalizedError, Equatable {
    case insertReturnedNoRows

    var errorDescription: String? {
        switch self {
        case .insertReturnedNoRows:
            return "Fleeting note could not be saved."
        }
    }
}

extension FleetingNote {
    static let tableName = "fleeting notes"

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
            .select("id, created_at, note")
            .order("created_at", ascending: false)
            .execute()
            .value

        return FleetingNote.sortedNewestFirst(rows)
    }

    func createFleetingNote(_ request: CreateFleetingNoteRequest) async throws -> FleetingNote {
        let inserted: [FleetingNote] = try await customsupabase
            .from(FleetingNote.tableName)
            .insert(request)
            .select("id, created_at, note")
            .execute()
            .value

        guard let note = inserted.first else {
            throw FleetingNotesError.insertReturnedNoRows
        }

        return note
    }
}
