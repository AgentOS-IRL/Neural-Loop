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

extension FleetingNote {
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
    // The backing Postgres table is `public."fleeting notes"`, so the space
    // stays centralized here instead of being duplicated across queries.
    fileprivate var fleetingNotesTableName: String { "fleeting notes" }

    func fetchFleetingNotes() async throws -> [FleetingNote] {
        let rows: [FleetingNote] = try await customsupabase
            .from(fleetingNotesTableName)
            .select("id, created_at, note")
            .order("created_at", ascending: false)
            .execute()
            .value

        return FleetingNote.sortedNewestFirst(rows)
    }
}
